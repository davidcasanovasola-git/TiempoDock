import AppKit
import SwiftUI

/// Qué se dibuja en el icono.
struct DockIconContent {
    var symbol: String
    var mainText: String?
    var caption: String?
    var style: SkyStyle

    static let placeholder = DockIconContent(symbol: "cloud.sun.fill", mainText: "--°", caption: nil, style: .clearDay)
    static let appIcon = DockIconContent(symbol: "cloud.sun.fill", mainText: nil, caption: nil, style: .clearDay)

    static func make(forecast f: Forecast, metric: DockMetric) -> DockIconContent {
        let now = WeatherCode.info(f.current.code, isDay: f.current.isDay)
        switch metric {
        case .temperature:
            return DockIconContent(symbol: now.symbol, mainText: Format.deg(f.current.temperature), caption: nil, style: now.style)
        case .feelsLike:
            return DockIconContent(symbol: now.symbol, mainText: Format.deg(f.current.feelsLike), caption: "Sensación", style: now.style)
        case .wind:
            return DockIconContent(symbol: "wind", mainText: Format.int(f.current.windSpeed), caption: f.windUnit.symbol, style: now.style)
        case .humidity:
            return DockIconContent(symbol: "humidity.fill", mainText: Format.int(f.current.humidity) + "%", caption: "Humedad", style: now.style)
        case .todayHighLow:
            guard let d = f.today else { return make(forecast: f, metric: .temperature) }
            let info = WeatherCode.info(d.code, isDay: true)
            return DockIconContent(symbol: info.symbol, mainText: "\(Format.deg(d.max))/\(Format.deg(d.min))", caption: "Hoy", style: now.style)
        case .tomorrowHighLow:
            guard let d = f.tomorrow else { return make(forecast: f, metric: .temperature) }
            let info = WeatherCode.info(d.code, isDay: true)
            return DockIconContent(symbol: info.symbol, mainText: "\(Format.deg(d.max))/\(Format.deg(d.min))", caption: "Mañana", style: info.style)
        case .precipitationChance:
            let p = f.today?.precipitationChance ?? 0
            return DockIconContent(symbol: "umbrella.fill", mainText: "\(p)%", caption: "Lluvia hoy", style: now.style)
        }
    }
}

/// Dibujo del icono en un lienzo de 1024×1024 (la rejilla estándar de iconos de macOS).
struct DockIconView: View {
    let content: DockIconContent

    private var symbolSize: CGFloat {
        if content.mainText == nil { return 540 }
        return content.caption == nil ? 330 : 270
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: content.style.colors, startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 186, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 4)
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 10)

            VStack(spacing: 4) {
                Image(systemName: content.symbol)
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: symbolSize, height: symbolSize)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
                if let caption = content.caption {
                    Text(caption)
                        .font(.system(size: 88, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                if let text = content.mainText {
                    Text(text)
                        .font(.system(size: 250, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
            }
            .frame(width: 720, height: 760)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
enum DockIconRenderer {
    static func cgImage(_ content: DockIconContent, pixels: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: DockIconView(content: content).environment(\.colorScheme, .dark))
        renderer.scale = pixels / 1024
        return renderer.cgImage
    }

    static func nsImage(_ content: DockIconContent, pixels: CGFloat = 512) -> NSImage? {
        guard let cg = cgImage(content, pixels: pixels) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: pixels, height: pixels))
    }

    static func update(store: WeatherStore) {
        let content: DockIconContent
        if let f = store.forecast {
            content = .make(forecast: f, metric: Prefs.currentDockMetric)
        } else {
            content = .placeholder
        }
        if let image = nsImage(content) {
            NSApp.applicationIconImage = image
        }
    }
}

/// Genera el .iconset que usa el script de compilación para el icono de Finder.
@MainActor
enum IconExporter {
    static func exportIconset(to path: String) {
        let dir = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sizes: [(String, CGFloat)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32),
            ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256),
            ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024),
        ]
        for (name, px) in sizes {
            guard let cg = DockIconRenderer.cgImage(.appIcon, pixels: px) else { continue }
            let rep = NSBitmapImageRep(cgImage: cg)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
    }
}
