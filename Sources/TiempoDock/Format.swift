import Foundation

enum Format {
    static var locale: Locale { AppLocale.current }

    static func deg(_ value: Double) -> String {
        let n = Int(value.rounded())
        return "\(n == 0 ? 0 : n)°"
    }

    static func int(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    static func compass(_ degrees: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].map { key -> String in
            let value = L("compass." + key)
            return value.hasPrefix("compass.") ? key : value
        }
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
        return names[index]
    }

    static func time(_ date: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        switch Prefs.currentTimeFormat {
        case .system: f.timeStyle = .short
        case .h24: f.dateFormat = "HH:mm"
        case .h12: f.setLocalizedDateFormatFromTemplate("hmma")
        }
        return f.string(from: date)
    }

    static func hour(_ date: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        switch Prefs.currentTimeFormat {
        case .system: f.setLocalizedDateFormatFromTemplate("j")
        case .h24: f.setLocalizedDateFormatFromTemplate("HH")
        case .h12: f.setLocalizedDateFormatFromTemplate("ha")
        }
        return f.string(from: date)
    }

    static func dayName(_ date: Date, index: Int, in tz: TimeZone) -> String {
        if index == 0 { return L("Today") }
        if index == 1 { return L("Tomorrow") }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        f.setLocalizedDateFormatFromTemplate("EEEd")
        return f.string(from: date).replacingOccurrences(of: ".", with: "").capitalized(with: locale)
    }

    static func precipitation(_ value: Double, _ unit: PrecipitationUnit) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = unit == .mm ? 1 : 2
        f.maximumFractionDigits = unit == .mm ? 1 : 2
        return (f.string(from: NSNumber(value: value)) ?? "\(value)") + " " + unit.symbol
    }
}
