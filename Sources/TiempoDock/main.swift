import AppKit

// Uso interno del script de compilación: genera el icono de la app.
let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--export-iconset"), i + 1 < arguments.count {
    MainActor.assumeIsolated {
        IconExporter.exportIconset(to: arguments[i + 1])
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
            let f = try await WeatherService.forecast(for: loc, temperatureUnit: .celsius, windUnit: .kmh)
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
