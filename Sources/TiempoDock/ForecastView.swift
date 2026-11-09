import SwiftUI

struct ForecastView: View {
    @EnvironmentObject var store: WeatherStore

    var body: some View {
        VStack(spacing: 0) {
            header
            if let f = store.forecast {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = store.errorMessage {
                            ErrorBanner(message: error)
                        }
                        CurrentSection(forecast: f)
                        HourlySection(forecast: f)
                        DailySection(forecast: f)
                        footer
                    }
                    .padding(20)
                }
            } else if let error = store.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                    HStack {
                        Button(L("Retry")) { Task { await store.refresh() } }
                        Button(L("Open Settings")) { (NSApp.delegate as? AppDelegate)?.showSettings() }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView(L("Loading weather…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 460, minHeight: 600)
        .background(
            LinearGradient(colors: sky.colors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
    }

    /// Fondo de la ventana: el mismo cielo que el icono del Dock.
    private var sky: SkyStyle {
        guard let f = store.forecast else { return .clearDay }
        return WeatherCode.info(f.current.code, isDay: f.current.isDay).style
    }

    private var header: some View {
        HStack(spacing: 10) {
            Picker(L("Location"), selection: Binding(
                get: { store.selectedLocation?.id },
                set: { if let id = $0 { store.select(id) } }
            )) {
                ForEach(store.locations) { loc in
                    Label(loc.name, systemImage: loc.isCurrentLocation ? "location.fill" : "mappin")
                        .tag(Optional(loc.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 260)

            Spacer()

            if store.isLoading {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(L("Refresh Now"))
            Button {
                (NSApp.delegate as? AppDelegate)?.showSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help(L("Settings"))
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            if let date = store.lastUpdatedSelected {
                Text(L("Updated at %@", Format.time(date, in: .current)))
            }
            Spacer()
            Link(L("Data: Open-Meteo.com"), destination: URL(string: "https://open-meteo.com")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Ahora

private struct CurrentSection: View {
    let forecast: Forecast

    var body: some View {
        let c = forecast.current
        let info = WeatherCode.info(c.code, isDay: c.isDay)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: info.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 64))
                    .frame(width: 84)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.deg(c.temperature))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                    Text(info.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let today = forecast.today {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L("High %@", Format.deg(today.max)))
                        Text(L("Low %@", Format.deg(today.min)))
                    }
                    .font(.title3)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    Detail(icon: "thermometer.medium", title: L("Feels like"), value: Format.deg(c.feelsLike))
                    Detail(icon: "humidity.fill", title: L("Humidity"), value: "\(Format.int(c.humidity))%")
                }
                GridRow {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.fill")
                            .rotationEffect(.degrees(c.windDirection + 180))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(L("Wind")).foregroundStyle(.secondary)
                        Text("\(Format.int(c.windSpeed)) \(forecast.windUnit.symbol) \(Format.compass(c.windDirection))")
                    }
                    Detail(icon: "drop.fill", title: L("Precipitation"), value: Format.precipitation(c.precipitation, forecast.precipitationUnit))
                }
                if let today = forecast.today {
                    GridRow {
                        Detail(icon: "sunrise.fill", title: L("Sunrise"), value: today.sunrise.map { Format.time($0, in: forecast.timeZone) } ?? "—")
                        Detail(icon: "sunset.fill", title: L("Sunset"), value: today.sunset.map { Format.time($0, in: forecast.timeZone) } ?? "—")
                    }
                }
            }
            .font(.callout)
        }
    }
}

private struct Detail: View {
    let icon: String
    let title: String
    let value: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title).foregroundStyle(.secondary)
            Text(value)
        }
    }
}

// MARK: - Por horas

private struct HourlySection: View {
    let forecast: Forecast

    var body: some View {
        Card(title: L("Next 24 Hours"), icon: "clock") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(forecast.upcomingHours.enumerated()), id: \.element.id) { index, hour in
                        let info = WeatherCode.info(hour.code, isDay: hour.isDay)
                        VStack(spacing: 6) {
                            Text(index == 0 ? L("Now") : Format.hour(hour.time, in: forecast.timeZone))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: info.symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.title2)
                                .frame(height: 28)
                            Text(rainText(hour.precipitationChance))
                                .font(.caption2)
                                .foregroundStyle(Color.rainChance)
                            Text(Format.deg(hour.temperature))
                                .font(.body.weight(.medium))
                        }
                        .frame(minWidth: 40)
                        .help(info.description)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
        }
    }

    private func rainText(_ p: Int?) -> String {
        guard let p, p >= 10 else { return " " }
        return "\(p)%"
    }
}

// MARK: - Por días

private struct DailySection: View {
    let forecast: Forecast

    var body: some View {
        let lowest = forecast.days.map(\.min).min() ?? 0
        let highest = forecast.days.map(\.max).max() ?? 1
        Card(title: L("Next %d Days", forecast.days.count), icon: "calendar") {
            VStack(spacing: 0) {
                ForEach(Array(forecast.days.enumerated()), id: \.element.id) { index, day in
                    let info = WeatherCode.info(day.code, isDay: true)
                    HStack(spacing: 10) {
                        Text(Format.dayName(day.date, index: index, in: forecast.timeZone))
                            .frame(width: 70, alignment: .leading)
                        Image(systemName: info.symbol)
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 26)
                            .help(info.description)
                        Text(rainText(day.precipitationChance))
                            .font(.caption)
                            .foregroundStyle(Color.rainChance)
                            .frame(width: 36, alignment: .leading)
                        Text(Format.deg(day.min))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        TemperatureBar(
                            low: day.min, high: day.max,
                            rangeLow: lowest, rangeHigh: highest,
                            current: index == 0 ? forecast.current.temperature : nil
                        )
                        Text(Format.deg(day.max))
                            .frame(width: 36, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    if index < forecast.days.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func rainText(_ p: Int?) -> String {
        guard let p, p >= 10 else { return "" }
        return "\(p)%"
    }
}

private struct TemperatureBar: View {
    let low: Double
    let high: Double
    let rangeLow: Double
    let rangeHigh: Double
    let current: Double?

    var body: some View {
        GeometryReader { geo in
            let span = max(rangeHigh - rangeLow, 1)
            let start = (low - rangeLow) / span * geo.size.width
            let width = max((high - low) / span * geo.size.width, 6)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width)
                    .offset(x: start)
                if let current {
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                        .frame(width: 8, height: 8)
                        .offset(x: min(max((current - rangeLow) / span * geo.size.width - 4, 0), geo.size.width - 8))
                }
            }
        }
        .frame(height: 8)
        .frame(minWidth: 80)
    }
}

// MARK: - Estilo

private extension Color {
    static let rainChance = Color(red: 0.62, green: 0.86, blue: 1.0)
}

/// Tarjeta translúcida sobre el fondo de cielo.
private struct Card<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.7))
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
