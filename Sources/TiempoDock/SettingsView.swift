import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            LocationsSettings()
                .tabItem { Label("Ubicaciones", systemImage: "mappin.and.ellipse") }
            DisplaySettings()
                .tabItem { Label("Dock y unidades", systemImage: "dock.rectangle") }
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(16)
        .frame(width: 520, height: 500)
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
            Text("Tus ubicaciones")
                .font(.headline)
            Text("Haz clic en una para mostrarla en el icono del Dock.")
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
                            Label("En el Dock", systemImage: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            store.remove(loc.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Eliminar")
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
                    Label("Añadir mi ubicación actual", systemImage: "location")
                }
            }

            Divider()

            Text("Añadir una ciudad")
                .font(.headline)
            HStack {
                TextField("Escribe una ciudad, p. ej. Valencia", text: $query)
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
                    Button("Añadir") {
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
                searchError = found.isEmpty ? "No se ha encontrado ninguna ciudad con ese nombre." : nil
            } catch {
                if !Task.isCancelled {
                    searchError = "Error al buscar: \(error.localizedDescription)"
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
    @AppStorage(Prefs.showMenuBar) private var showMenuBar = false

    var body: some View {
        Form {
            Section("Icono del Dock") {
                Picker("Mostrar", selection: $metric) {
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
            Section("Unidades") {
                Picker("Temperatura", selection: $temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { Text($0.title).tag($0) }
                }
                Picker("Viento", selection: $windUnit) {
                    ForEach(WindUnit.allCases) { Text($0.symbol).tag($0) }
                }
            }
            Section("Barra de menús") {
                Toggle("Mostrar también la temperatura en la barra de menús", isOn: $showMenuBar)
            }
        }
        .formStyle(.grouped)
        .onChange(of: metric) { _ in store.displaySettingsChanged() }
        .onChange(of: showMenuBar) { _ in store.displaySettingsChanged() }
        .onChange(of: temperatureUnit) { _ in store.unitsChanged() }
        .onChange(of: windUnit) { _ in store.unitsChanged() }
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject var store: WeatherStore
    @AppStorage(Prefs.refreshMinutes) private var refreshMinutes = 15
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Actualización") {
                Picker("Actualizar cada", selection: $refreshMinutes) {
                    Text("5 minutos").tag(5)
                    Text("10 minutos").tag(10)
                    Text("15 minutos").tag(15)
                    Text("30 minutos").tag(30)
                    Text("1 hora").tag(60)
                }
                Text("También se actualiza al despertar el Mac y al cambiar de ubicación.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Inicio") {
                Toggle("Abrir TiempoDock al iniciar sesión", isOn: $launchAtLogin)
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Acerca de") {
                Text("TiempoDock es gratuito y de código abierto (licencia MIT). Los datos meteorológicos son de Open-Meteo.com (CC BY 4.0), sin cuenta ni clave de API.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: refreshMinutes) { _ in store.scheduleTimer() }
        .onChange(of: launchAtLogin) { enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                loginError = nil
            } catch {
                loginError = "No se pudo cambiar: \(error.localizedDescription). Asegúrate de que la app está en la carpeta Aplicaciones."
            }
        }
    }
}
