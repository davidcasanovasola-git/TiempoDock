import AppKit

/// Actualizaciones automáticas desde GitHub Releases.
///
/// Cada versión publicada (etiqueta `vX.Y.Z`) lleva adjunto `TiempoDock.zip`.
/// La app consulta la última versión, y si es más nueva la descarga, comprueba
/// que es TiempoDock con una firma válida, se cierra, se reemplaza y se vuelve a abrir.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    static let repository = "davidcasanovasola-git/TiempoDock"
    static let assetName = "TiempoDock.zip"

    @Published private(set) var statusText: String?
    @Published private(set) var isWorking = false
    private var timer: Timer?

    enum UpdateError: LocalizedError {
        case noReleases
        case badStatus(Int)
        case missingAsset(String)
        case invalidApp
        case notWritable(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .noReleases: return "Todavía no hay versiones publicadas en GitHub."
            case .badStatus(let c): return "GitHub respondió con el código \(c)."
            case .missingAsset(let v): return "La versión \(v) no incluye TiempoDock.zip."
            case .invalidApp: return "El archivo descargado no es una versión válida de TiempoDock."
            case .notWritable(let p): return "No se puede escribir en \(p)."
            case .commandFailed(let c): return "Falló: \(c)"
            }
        }
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let assets: [Asset]
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // MARK: - Comprobación periódica

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.automaticCheck() }
        }
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            await automaticCheck()
        }
    }

    private func automaticCheck() async {
        guard UserDefaults.standard.bool(forKey: Prefs.autoUpdate) else { return }
        await check(userInitiated: false)
    }

    // MARK: - Buscar e instalar

    func check(userInitiated: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        statusText = "Buscando actualizaciones…"
        do {
            let release = try await latestRelease()
            let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard Self.isVersion(latest, newerThan: currentVersion) else {
                statusText = "Tienes la última versión (\(currentVersion))."
                if userInitiated { showAlert(statusText!) }
                return
            }
            guard let asset = release.assets.first(where: { $0.name == Self.assetName }) else {
                throw UpdateError.missingAsset(latest)
            }
            statusText = "Descargando la versión \(latest)…"
            try await install(from: asset.browser_download_url, version: latest)
        } catch {
            statusText = "No se pudo actualizar: \(error.localizedDescription)"
            if userInitiated { showAlert(statusText!) }
        }
    }

    private func latestRelease() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TiempoDock/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { throw UpdateError.noReleases }
        guard code == 200 else { throw UpdateError.badStatus(code) }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    private func install(from url: URL, version: String) async throws {
        let fm = FileManager.default
        let target = Bundle.main.bundleURL
        let parent = target.deletingLastPathComponent().path
        guard fm.isWritableFile(atPath: parent) else { throw UpdateError.notWritable(parent) }

        let work = fm.temporaryDirectory.appendingPathComponent("TiempoDockUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let (downloaded, response) = try await URLSession.shared.download(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw UpdateError.badStatus(code) }
        let zip = work.appendingPathComponent("update.zip")
        try fm.moveItem(at: downloaded, to: zip)

        statusText = "Preparando la versión \(version)…"
        try await run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
        let newApp = work.appendingPathComponent("TiempoDock.app")
        guard let bundle = Bundle(url: newApp),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.invalidApp
        }
        try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])

        // Un pequeño script espera a que la app se cierre, la reemplaza y la vuelve a abrir.
        let script = """
        while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.3; done
        /bin/rm -rf "$2"
        /bin/mv "$3" "$2"
        if [ "$5" = "1" ]; then /usr/bin/open "$2" --args --background; else /usr/bin/open "$2"; fi
        /bin/rm -rf "$4"
        """
        let background = (NSApp.delegate as? AppDelegate)?.hasVisibleWindows == false
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "tiempodock-update",
                             String(ProcessInfo.processInfo.processIdentifier),
                             target.path, newApp.path, work.path, background ? "1" : "0"]
        try process.run()

        statusText = "Instalando la versión \(version)…"
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: tool)
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: UpdateError.commandFailed(([tool] + args).joined(separator: " ")))
                }
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }

    private func showAlert(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Actualizaciones de TiempoDock"
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Versiones

    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
