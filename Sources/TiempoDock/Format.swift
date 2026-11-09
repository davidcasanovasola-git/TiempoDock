import Foundation

enum Format {
    static let locale = Locale(identifier: "es_ES")

    static func deg(_ value: Double) -> String {
        let n = Int(value.rounded())
        return "\(n == 0 ? 0 : n)°"
    }

    static func int(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    static func compass(_ degrees: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
        return names[index]
    }

    static func time(_ date: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func hour(_ date: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        f.dateFormat = "HH"
        return f.string(from: date) + " h"
    }

    static func dayName(_ date: Date, index: Int, in tz: TimeZone) -> String {
        if index == 0 { return "Hoy" }
        if index == 1 { return "Mañana" }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = tz
        f.dateFormat = "EEE d"
        return f.string(from: date).replacingOccurrences(of: ".", with: "").capitalized(with: locale)
    }
}
