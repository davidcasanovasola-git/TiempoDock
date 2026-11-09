import Foundation

// MARK: - Preferencias

enum Prefs {
    static let dockMetric = "dockMetric"
    static let temperatureUnit = "temperatureUnit"
    static let windUnit = "windUnit"
    static let refreshMinutes = "refreshMinutes"
    static let showMenuBar = "showMenuBar"
    static let locations = "locations"
    static let selectedLocationID = "selectedLocationID"
    static let autoUpdate = "autoUpdate"

    static func register() {
        UserDefaults.standard.register(defaults: [
            autoUpdate: true,
            dockMetric: DockMetric.temperature.rawValue,
            temperatureUnit: TemperatureUnit.celsius.rawValue,
            windUnit: WindUnit.kmh.rawValue,
            refreshMinutes: 15,
            showMenuBar: false,
        ])
    }

    static var currentDockMetric: DockMetric {
        DockMetric(rawValue: UserDefaults.standard.string(forKey: dockMetric) ?? "") ?? .temperature
    }

    static var currentTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: temperatureUnit) ?? "") ?? .celsius
    }

    static var currentWindUnit: WindUnit {
        WindUnit(rawValue: UserDefaults.standard.string(forKey: windUnit) ?? "") ?? .kmh
    }

    static var currentRefreshMinutes: Int {
        max(5, UserDefaults.standard.integer(forKey: refreshMinutes))
    }
}

enum DockMetric: String, CaseIterable, Identifiable {
    case temperature, feelsLike, wind, humidity, todayHighLow, tomorrowHighLow, precipitationChance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .temperature: return "Temperatura actual"
        case .feelsLike: return "Sensación térmica"
        case .wind: return "Viento"
        case .humidity: return "Humedad"
        case .todayHighLow: return "Máxima / mínima de hoy"
        case .tomorrowHighLow: return "Máxima / mínima de mañana"
        case .precipitationChance: return "Probabilidad de lluvia hoy"
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }
    var title: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }
}

enum WindUnit: String, CaseIterable, Identifiable {
    case kmh, ms, mph, kn
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .kmh: return "km/h"
        case .ms: return "m/s"
        case .mph: return "mph"
        case .kn: return "nudos"
        }
    }
}

// MARK: - Ubicaciones

struct SavedLocation: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var detail: String
    var latitude: Double
    var longitude: Double
    var isCurrentLocation = false

    var hasCoordinates: Bool { latitude != 0 || longitude != 0 }

    static func currentPlaceholder() -> SavedLocation {
        SavedLocation(name: "Ubicación actual", detail: "", latitude: 0, longitude: 0, isCurrentLocation: true)
    }
}

// MARK: - Previsión

struct Forecast {
    struct Current {
        let time: Date
        let temperature: Double
        let feelsLike: Double
        let humidity: Double
        let windSpeed: Double
        let windDirection: Double
        let precipitation: Double
        let code: Int
        let isDay: Bool
    }

    struct Hour: Identifiable {
        var id: Date { time }
        let time: Date
        let temperature: Double
        let code: Int
        let isDay: Bool
        let precipitationChance: Int?
    }

    struct Day: Identifiable {
        var id: Date { date }
        let date: Date
        let code: Int
        let max: Double
        let min: Double
        let precipitationChance: Int?
        let sunrise: Date?
        let sunset: Date?
    }

    let timeZone: TimeZone
    let current: Current
    let hours: [Hour]
    let days: [Day]
    let temperatureUnit: TemperatureUnit
    let windUnit: WindUnit

    /// Las próximas 24 horas empezando por la hora en curso.
    var upcomingHours: [Hour] {
        let now = Date()
        return Array(hours.filter { $0.time > now.addingTimeInterval(-3600) }.prefix(24))
    }

    var today: Day? { days.first }
    var tomorrow: Day? { days.count > 1 ? days[1] : nil }
}
