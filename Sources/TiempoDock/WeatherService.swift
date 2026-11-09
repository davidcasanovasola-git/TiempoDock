import Foundation

/// Cliente de Open-Meteo (https://open-meteo.com). Gratis y sin clave de API.
enum WeatherService {
    enum ServiceError: LocalizedError {
        case badStatus(Int)
        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "El servidor respondió con el código \(code)"
            }
        }
    }

    static func forecast(for location: SavedLocation, temperatureUnit: TemperatureUnit, windUnit: WindUnit) async throws -> Forecast {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m,wind_direction_10m,precipitation"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "16"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "temperature_unit", value: temperatureUnit.rawValue),
            URLQueryItem(name: "wind_speed_unit", value: windUnit.rawValue),
        ]
        let data = try await fetch(components.url!)
        let raw = try JSONDecoder().decode(RawForecast.self, from: data)
        return raw.toForecast(temperatureUnit: temperatureUnit, windUnit: windUnit)
    }

    static func searchCities(_ query: String) async throws -> [SavedLocation] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let data = try await fetch(components.url!)
        let raw = try JSONDecoder().decode(RawGeocoding.self, from: data)
        return (raw.results ?? []).map { r in
            let detail = [r.admin1, r.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            return SavedLocation(name: r.name, detail: detail, latitude: r.latitude, longitude: r.longitude)
        }
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ServiceError.badStatus(http.statusCode)
        }
        return data
    }
}

// MARK: - JSON de Open-Meteo

private struct RawForecast: Decodable {
    let utc_offset_seconds: Int
    let timezone: String
    let current: Current
    let hourly: Hourly
    let daily: Daily

    struct Current: Decodable {
        let time: TimeInterval
        let temperature_2m: Double
        let apparent_temperature: Double
        let relative_humidity_2m: Double
        let is_day: Int
        let weather_code: Int
        let wind_speed_10m: Double
        let wind_direction_10m: Double
        let precipitation: Double
    }

    struct Hourly: Decodable {
        let time: [TimeInterval]
        let temperature_2m: [Double?]
        let weather_code: [Int?]
        let precipitation_probability: [Double?]
        let is_day: [Int?]
    }

    struct Daily: Decodable {
        let time: [TimeInterval]
        let weather_code: [Int?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Double?]
        let sunrise: [TimeInterval?]
        let sunset: [TimeInterval?]
    }

    func toForecast(temperatureUnit: TemperatureUnit, windUnit: WindUnit) -> Forecast {
        let tz = TimeZone(identifier: timezone) ?? TimeZone(secondsFromGMT: utc_offset_seconds) ?? .current

        let current = Forecast.Current(
            time: Date(timeIntervalSince1970: self.current.time),
            temperature: self.current.temperature_2m,
            feelsLike: self.current.apparent_temperature,
            humidity: self.current.relative_humidity_2m,
            windSpeed: self.current.wind_speed_10m,
            windDirection: self.current.wind_direction_10m,
            precipitation: self.current.precipitation,
            code: self.current.weather_code,
            isDay: self.current.is_day == 1
        )

        var hours: [Forecast.Hour] = []
        for i in hourly.time.indices {
            guard let t = hourly.temperature_2m[safe: i] ?? nil,
                  let c = hourly.weather_code[safe: i] ?? nil else { continue }
            hours.append(Forecast.Hour(
                time: Date(timeIntervalSince1970: hourly.time[i]),
                temperature: t,
                code: c,
                isDay: (hourly.is_day[safe: i] ?? nil) == 1,
                precipitationChance: (hourly.precipitation_probability[safe: i] ?? nil).map { Int($0.rounded()) }
            ))
        }

        var days: [Forecast.Day] = []
        for i in daily.time.indices {
            guard let c = daily.weather_code[safe: i] ?? nil,
                  let hi = daily.temperature_2m_max[safe: i] ?? nil,
                  let lo = daily.temperature_2m_min[safe: i] ?? nil else { continue }
            days.append(Forecast.Day(
                date: Date(timeIntervalSince1970: daily.time[i]),
                code: c,
                max: hi,
                min: lo,
                precipitationChance: (daily.precipitation_probability_max[safe: i] ?? nil).map { Int($0.rounded()) },
                sunrise: (daily.sunrise[safe: i] ?? nil).map { Date(timeIntervalSince1970: $0) },
                sunset: (daily.sunset[safe: i] ?? nil).map { Date(timeIntervalSince1970: $0) }
            ))
        }

        return Forecast(timeZone: tz, current: current, hours: hours, days: days,
                        temperatureUnit: temperatureUnit, windUnit: windUnit)
    }
}

private struct RawGeocoding: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
    }
    let results: [Result]?
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
