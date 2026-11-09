import SwiftUI

/// Estilo de fondo del icono según el tipo de tiempo.
enum SkyStyle {
    case clearDay, clearNight, cloudy, rain, storm, snow, fog

    var colors: [Color] {
        switch self {
        case .clearDay: return [Color(red: 0.25, green: 0.62, blue: 0.98), Color(red: 0.10, green: 0.40, blue: 0.85)]
        case .clearNight: return [Color(red: 0.12, green: 0.16, blue: 0.38), Color(red: 0.04, green: 0.05, blue: 0.18)]
        case .cloudy: return [Color(red: 0.55, green: 0.63, blue: 0.73), Color(red: 0.36, green: 0.44, blue: 0.55)]
        case .rain: return [Color(red: 0.33, green: 0.43, blue: 0.58), Color(red: 0.18, green: 0.25, blue: 0.38)]
        case .storm: return [Color(red: 0.30, green: 0.27, blue: 0.42), Color(red: 0.13, green: 0.11, blue: 0.22)]
        case .snow: return [Color(red: 0.62, green: 0.74, blue: 0.86), Color(red: 0.42, green: 0.55, blue: 0.70)]
        case .fog: return [Color(red: 0.60, green: 0.62, blue: 0.66), Color(red: 0.42, green: 0.44, blue: 0.48)]
        }
    }
}

struct WeatherInfo {
    let description: String
    let symbol: String
    let style: SkyStyle
}

/// Traduce los códigos WMO que devuelve Open-Meteo.
enum WeatherCode {
    static func info(_ code: Int, isDay: Bool) -> WeatherInfo {
        switch code {
        case 0:
            return WeatherInfo(description: L("Clear"), symbol: isDay ? "sun.max.fill" : "moon.stars.fill", style: isDay ? .clearDay : .clearNight)
        case 1:
            return WeatherInfo(description: L("Mostly clear"), symbol: isDay ? "sun.max.fill" : "moon.fill", style: isDay ? .clearDay : .clearNight)
        case 2:
            return WeatherInfo(description: L("Partly cloudy"), symbol: isDay ? "cloud.sun.fill" : "cloud.moon.fill", style: isDay ? .clearDay : .clearNight)
        case 3:
            return WeatherInfo(description: L("Cloudy"), symbol: "cloud.fill", style: .cloudy)
        case 45, 48:
            return WeatherInfo(description: L("Fog"), symbol: "cloud.fog.fill", style: .fog)
        case 51, 53, 55:
            return WeatherInfo(description: L("Drizzle"), symbol: "cloud.drizzle.fill", style: .rain)
        case 56, 57:
            return WeatherInfo(description: L("Freezing drizzle"), symbol: "cloud.sleet.fill", style: .snow)
        case 61, 63:
            return WeatherInfo(description: L("Rain"), symbol: "cloud.rain.fill", style: .rain)
        case 65:
            return WeatherInfo(description: L("Heavy rain"), symbol: "cloud.heavyrain.fill", style: .rain)
        case 66, 67:
            return WeatherInfo(description: L("Freezing rain"), symbol: "cloud.sleet.fill", style: .snow)
        case 71, 73:
            return WeatherInfo(description: L("Snow"), symbol: "cloud.snow.fill", style: .snow)
        case 75:
            return WeatherInfo(description: L("Heavy snow"), symbol: "snowflake", style: .snow)
        case 77:
            return WeatherInfo(description: L("Snow grains"), symbol: "cloud.snow.fill", style: .snow)
        case 80, 81:
            return WeatherInfo(description: L("Showers"), symbol: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill", style: .rain)
        case 82:
            return WeatherInfo(description: L("Heavy showers"), symbol: "cloud.heavyrain.fill", style: .rain)
        case 85, 86:
            return WeatherInfo(description: L("Snow showers"), symbol: "cloud.snow.fill", style: .snow)
        case 95:
            return WeatherInfo(description: L("Thunderstorm"), symbol: "cloud.bolt.rain.fill", style: .storm)
        case 96, 99:
            return WeatherInfo(description: L("Thunderstorm with hail"), symbol: "cloud.hail.fill", style: .storm)
        default:
            return WeatherInfo(description: L("Unknown"), symbol: "questionmark.circle", style: .cloudy)
        }
    }
}
