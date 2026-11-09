import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            LocationsSettings()
                .tabItem { Label(L("Locations"), systemImage: "mappin.and.ellipse") }
            DisplaySettings()
                .tabItem { Label(L("Dock & Units"), systemImage: "dock.rectangle") }
            GeneralSettings()
                .tabItem { Label(L("General"), systemImage: "gearshape") }
        }
        .padding(16)
        .frame(width: 540, height: 600)
    }
}

// MARK: - Ubicaciones

private struct LocationsSettings: View {
    @EnvironmentObject var store: WeatherStore
    @State private var query = ""
    @State private var results: [SavedLocation] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Your Locations"))
                .font(.headline)
            Text(L("Click one to show it in the Dock icon."))
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(store.locations) { loc in
                    HStack {
                        Image(systemName: loc.isCurrentLocation ? "location.fill" : "mappin")
                            .foregroundStyle(loc.isCurrentLocation ? .blue : .red)
                            .frame(width: 18)
                        VStack(alignment: .leading) {
                            Text(loc.name)
                            if !loc.detail.isEmpty {
                                Text(loc.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if loc.id == store.selectedLocation?.id {
                            Label(L("In Dock"), systemImage: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            store.remove(loc.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help(L("Remove"))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { store.select(loc.id) }
                }
                .onMove { store.move(from: $0, to: $1) }
            }
            .frame(minHeight: 130)

            if !store.locations.contains(where: \.isCurrentLocation) {
                Button {
                    store.addCurrentLocation()
                } label: {
                    Label(L("Add My Current Location"), systemImage: "location")
                }
            }

            Divider()

            Text(L("Add a City"))
                .font(.headline)
            HStack {
                TextField(L("Type a city, e.g. London"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { search(immediately: true) }
                    .onChange(of: query) { _ in search(immediately: false) }
                if searching { ProgressView().controlSize(.small) }
            }
            if let searchError {
                Text(searchError).font(.caption).foregroundStyle(.red)
            }
            List(results) { result in
                HStack {
                    VStack(alignment: .leading) {
                        Text(result.name)
                        Text(result.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L("Add")) {
                        store.add(result)
                        query = ""
                        results = []
                    }
                }
            }
            .frame(minHeight: 110)
        }
    }

    private func search(immediately: Bool) {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            results = []
            searching = false
            return
        }
        searchTask = Task {
            if !immediately {
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            guard !Task.isCancelled else { return }
            searching = true
            defer { searching = false }
            do {
                let found = try await WeatherService.searchCities(text)
                guard !Task.isCancelled else { return }
                results = found
                searchError = found.isEmpty ? L("No city found with that name.") : nil
            } catch {
                if !Task.isCancelled {
                    searchError = L("Search failed: %@", error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Dock y unidades

private struct DisplaySettings: View {
    @EnvironmentObject var store: WeatherStore
    @AppStorage(Prefs.dockMetric) private var metric: DockMetric = .temperature
    @AppStorage(Prefs.temperatureUnit) private var temperatureUnit: TemperatureUnit = .celsius
    @AppStorage(Prefs.windUnit) private var windUnit: WindUnit = .kmh
    @AppStorage(Prefs.precipitationUnit) private var precipitationUnit: PrecipitationUnit = .mm
    @AppStorage(Prefs.timeFormat) private var timeFormat: TimeFormat = .system
    @AppStorage(Prefs.showMenuBar) private var showMenuBar = false

    var body: some View {
        Form {
            Section(L("Dock Icon")) {
                Picker(L("Show"), selection: $metric) {
                    ForEach(DockMetric.allCases) { Text($0.title).tag($0) }
                }
                if let f = store.forecast, let image = DockIconRenderer.nsImage(.make(forecast: f, metric: metric), pixels: 256) {
                    HStack {
                        Spacer()
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: 96, height: 96)
                        Spacer()
                    }
                }
            }
            Section(L("Units")) {
                Picker(L("Temperature"), selection: $temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { Text($0.title).tag($0) }
                }
                Picker(L("Wind"), selection: $windUnit) {
                    ForEach(WindUnit.allCases) { Text($0.title).tag($0) }
                }
                Picker(L("Precipitation"), selection: $precipitationUnit) {
                    ForEach(PrecipitationUnit.allCases) { Text($0.title).tag($0) }
                }
                Picker(L("Time format"), selection: $timeFormat) {
                    ForEach(TimeFormat.allCases) { Text($0.title).tag($0) }
                }
            }
            Section(L("Menu Bar")) {
                Toggle(L("Also show the temperature in the menu bar"), isOn: $showMenuBar)
            }
        }
        .formStyle(.grouped)
        .onChange(of: metric) { _ in store.displaySettingsChanged() }
        .onChange(of: showMenuBar) { _ in store.displaySettingsChanged() }
        .onChange(of: temperatureUnit) { _ in store.unitsChanged() }
        .onChange(of: windUnit) { _ in store.unitsChanged() }
        .onChange(of: precipitationUnit) { _ in store.unitsChanged() }
        .onChange(of: timeFormat) { _ in store.displaySettingsChanged() }
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject var store: WeatherStore
    @AppStorage(Prefs.refreshMinutes) private var refreshMinutes = 15
    @AppStorage(Prefs.autoUpdate) private var autoUpdate = true
    @ObservedObject private var updater = Updater.shared
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var needsApproval = LoginItem.needsApproval
    @State private var loginError: String?

    var body: some View {
        Form {
            Section(L("Refresh")) {
                Picker(L("Refresh every"), selection: $refreshMinutes) {
                    Text(L("%d minutes", 5)).tag(5)
                    Text(L("%d minutes", 10)).tag(10)
                    Text(L("%d minutes", 15)).tag(15)
                    Text(L("%d minutes", 30)).tag(30)
                    Text(L("1 hour")).tag(60)
                }
                Text(L("It also refreshes when your Mac wakes up and when you change location."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L("Startup")) {
                Toggle(L("Open TiempoDock at login"), isOn: $launchAtLogin)
                Text(L("At login it opens without a window: only the Dock icon appears."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if needsApproval {
                    HStack {
                        Text(L("macOS needs you to approve it in Login Items."))
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button(L("Open System Settings")) { LoginItem.openSystemSettings() }
                    }
                }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section(L("Updates")) {
                Toggle(L("Check for and install updates automatically"), isOn: $autoUpdate)
                HStack {
                    Text(L("Version %@", updater.currentVersion))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if updater.isWorking { ProgressView().controlSize(.small) }
                    Button(L("Check Now")) {
                        Task { await updater.check(userInitiated: true) }
                    }
                    .disabled(updater.isWorking)
                }
                if let status = updater.statusText {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(L("About")) {
                Text(L("TiempoDock is free and open source (MIT license). Weather data comes from Open-Meteo.com (CC BY 4.0), with no account or API key."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: refreshMinutes) { _ in store.scheduleTimer() }
        .onChange(of: launchAtLogin) { enabled in
            do {
                try LoginItem.setEnabled(enabled)
                needsApproval = LoginItem.needsApproval
                loginError = nil
            } catch {
                loginError = L("Couldn't change it: %@. Make sure the app is in the Applications folder.", error.localizedDescription)
            }
        }
    }
}
