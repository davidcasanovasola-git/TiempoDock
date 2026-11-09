import AppKit
import SwiftUI

// Uso interno del script de compilación: genera el icono de la app.
let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--export-iconset"), i + 1 < arguments.count {
    MainActor.assumeIsolated {
        IconExporter.exportIconset(to: arguments[i + 1])
    }
    exit(0)
}

// Uso de desarrollo: captura el icono y la ventana con el tiempo real de una ciudad
// (para el README). No toca las preferencias del usuario.
// TiempoDock --snapshot <carpeta> <nombre-archivo> <ciudad> <latitud> <longitud> [light|dark]
if let i = arguments.firstIndex(of: "--snapshot"), i + 5 < arguments.count,
   let lat = Double(arguments[i + 4]), let lon = Double(arguments[i + 5]) {
    let dir = URL(fileURLWithPath: arguments[i + 1])
    let slug = arguments[i + 2]
    let city = arguments[i + 3]
    let dark = arguments.count > i + 6 && arguments[i + 6] == "dark"
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    Task { @MainActor in
        func writePNG(_ rep: NSBitmapImageRep, _ name: String) {
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(name))
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let loc = SavedLocation(name: city, detail: "", latitude: lat, longitude: lon)
            let f = try await WeatherService.forecast(for: loc, temperatureUnit: Prefs.currentTemperatureUnit, windUnit: Prefs.currentWindUnit)

            if let cg = DockIconRenderer.cgImage(.make(forecast: f, metric: .temperature), pixels: 256) {
                writePNG(NSBitmapImageRep(cgImage: cg), "\(slug)-icon.png")
            }

            let store = WeatherStore(preview: loc, forecast: f)
            let size = NSSize(width: 480, height: 760)
            let host = NSHostingView(rootView: ForecastView().environmentObject(store).frame(width: size.width, height: size.height))
            host.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 800_000_000)
            host.layoutSubtreeIfNeeded()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                writePNG(rep, "\(slug)-window.png")
            }
            let info = WeatherCode.info(f.current.code, isDay: f.current.isDay)
            print("\(city): \(Format.deg(f.current.temperature)) \(info.description)")
            exit(0)
        } catch {
            print("ERROR \(city): \(error)")
            exit(1)
        }
    }
    RunLoop.main.run()
}

// Uso de desarrollo: dibuja iconos de muestra (para el README).
if let i = arguments.firstIndex(of: "--render-samples"), i + 1 < arguments.count {
    let samples: [(String, Int, Bool, String)] = [
        ("sunny", 0, true, "24°"), ("partly", 2, true, "19°"), ("rain", 63, true, "14°"),
        ("storm", 95, true, "17°"), ("snow", 73, true, "-2°"), ("night", 0, false, "11°"),
    ]
    MainActor.assumeIsolated {
        try? FileManager.default.createDirectory(atPath: arguments[i + 1], withIntermediateDirectories: true)
        for (name, code, isDay, text) in samples {
            let info = WeatherCode.info(code, isDay: isDay)
            let content = DockIconContent(symbol: info.symbol, mainText: text, caption: nil, style: info.style)
            if let cg = DockIconRenderer.cgImage(content, pixels: 256),
               let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: arguments[i + 1]).appendingPathComponent("\(name).png"))
            }
        }
    }
    exit(0)
}

// Uso de desarrollo: dibuja el icono con datos reales de una ciudad para revisarlo.
// TiempoDock --render-preview <carpeta> <latitud> <longitud>
if let i = arguments.firstIndex(of: "--render-preview"), i + 3 < arguments.count,
   let lat = Double(arguments[i + 2]), let lon = Double(arguments[i + 3]) {
    let dir = arguments[i + 1]
    Task { @MainActor in
        let loc = SavedLocation(name: "Prueba", detail: "", latitude: lat, longitude: lon)
        do {
            let f = try await WeatherService.forecast(for: loc, temperatureUnit: Prefs.currentTemperatureUnit, windUnit: Prefs.currentWindUnit)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            for metric in DockMetric.allCases {
                if let cg = DockIconRenderer.cgImage(.make(forecast: f, metric: metric), pixels: 256),
                   let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(metric.rawValue).png"))
                }
            }
            print("OK", Format.deg(f.current.temperature), f.hours.count, "horas", f.days.count, "días")
            exit(0)
        } catch {
            print("ERROR", error)
            exit(1)
        }
    }
    RunLoop.main.run()
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) {
        app.run()
    }
}
