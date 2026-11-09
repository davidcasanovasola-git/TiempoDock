import AppKit
import CoreLocation

/// Estado central: ubicaciones guardadas, previsiones y temporizador de actualización.
@MainActor
final class WeatherStore: NSObject, ObservableObject {
    static let shared = WeatherStore()

    @Published private(set) var locations: [SavedLocation] = []
    @Published private(set) var selectedID: UUID?
    @Published private(set) var forecasts: [UUID: Forecast] = [:]
    @Published private(set) var lastUpdated: [UUID: Date] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Se llama cada vez que hay que redibujar el icono del Dock y la barra de menús.
    var onChange: (() -> Void)?

    private var timer: Timer?
    private let locationManager = CLLocationManager()
    private var started = false

    var selectedLocation: SavedLocation? {
        locations.first { $0.id == selectedID } ?? locations.first
    }

    var forecast: Forecast? {
        selectedLocation.flatMap { forecasts[$0.id] }
    }

    var lastUpdatedSelected: Date? {
        selectedLocation.flatMap { lastUpdated[$0.id] }
    }

    override init() {
        super.init()
        loadLocations()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Ciclo de vida

    func start() {
        guard !started else { return }
        started = true
        if locations.isEmpty {
            if CLLocationManager.locationServicesEnabled() {
                locations = [SavedLocation.currentPlaceholder()]
                selectedID = locations[0].id
                saveLocations()
            } else {
                errorMessage = "Este Mac no tiene la localización activada. Añade tu ciudad en Ajustes › Ubicaciones."
                DispatchQueue.main.async { (NSApp.delegate as? AppDelegate)?.showSettings() }
            }
        }
        scheduleTimer()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                // Tras despertar, la red tarda unos segundos en volver.
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await WeatherStore.shared.tick()
            }
        }
        Task { await tick() }
    }

    func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(Prefs.currentRefreshMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in await WeatherStore.shared.tick() }
        }
        timer?.tolerance = 60
    }

    private func tick() async {
        if selectedLocation?.isCurrentLocation == true {
            requestLocation()
        }
        await refresh()
    }

    // MARK: - Datos

    func refresh() async {
        guard let location = selectedLocation else {
            onChange?()
            return
        }
        guard location.hasCoordinates else {
            // Ubicación actual aún sin coordenadas: esperamos a CoreLocation.
            requestLocation()
            onChange?()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await WeatherService.forecast(
                for: location,
                temperatureUnit: Prefs.currentTemperatureUnit,
                windUnit: Prefs.currentWindUnit
            )
            forecasts[location.id] = result
            lastUpdated[location.id] = Date()
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo actualizar el tiempo: \(error.localizedDescription)"
        }
        onChange?()
    }

    func select(_ id: UUID) {
        guard id != selectedID else { return }
        selectedID = id
        UserDefaults.standard.set(id.uuidString, forKey: Prefs.selectedLocationID)
        onChange?()
        Task {
            if selectedLocation?.isCurrentLocation == true { requestLocation() }
            await refresh()
        }
    }

    func add(_ location: SavedLocation) {
        var new = location
        new.id = UUID()
        locations.append(new)
        saveLocations()
        select(new.id)
    }

    func addCurrentLocation() {
        guard !locations.contains(where: \.isCurrentLocation) else { return }
        let loc = SavedLocation.currentPlaceholder()
        locations.insert(loc, at: 0)
        saveLocations()
        select(loc.id)
    }

    func remove(_ id: UUID) {
        locations.removeAll { $0.id == id }
        forecasts[id] = nil
        lastUpdated[id] = nil
        if selectedID == id { selectedID = locations.first?.id }
        saveLocations()
        onChange?()
        Task { await refresh() }
    }

    func move(from source: IndexSet, to destination: Int) {
        locations.move(fromOffsets: source, toOffset: destination)
        saveLocations()
    }

    /// Cambió lo que muestra el Dock o la barra de menús: solo hay que redibujar.
    func displaySettingsChanged() {
        onChange?()
    }

    /// Cambiaron las unidades: hay que volver a pedir los datos.
    func unitsChanged() {
        forecasts.removeAll()
        Task { await refresh() }
    }

    // MARK: - Persistencia

    private func loadLocations() {
        if let data = UserDefaults.standard.data(forKey: Prefs.locations),
           let saved = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            locations = saved
        }
        if let s = UserDefaults.standard.string(forKey: Prefs.selectedLocationID), let id = UUID(uuidString: s) {
            selectedID = id
        }
        if selectedID == nil || !locations.contains(where: { $0.id == selectedID }) {
            selectedID = locations.first?.id
        }
    }

    private func saveLocations() {
        if let data = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(data, forKey: Prefs.locations)
        }
        if let id = selectedID {
            UserDefaults.standard.set(id.uuidString, forKey: Prefs.selectedLocationID)
        }
    }

    // MARK: - Ubicación actual

    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "TiempoDock no tiene permiso para usar tu ubicación. Actívalo en Ajustes del Sistema › Privacidad y seguridad › Localización, o añade una ciudad en los ajustes de la app."
            onChange?()
        default:
            locationManager.requestLocation()
        }
    }

    fileprivate func updateCurrentLocation(latitude: Double, longitude: Double) async {
        guard let index = locations.firstIndex(where: \.isCurrentLocation) else { return }
        let old = locations[index]
        let newLocation = CLLocation(latitude: latitude, longitude: longitude)
        let moved = !old.hasCoordinates ||
            CLLocation(latitude: old.latitude, longitude: old.longitude).distance(from: newLocation) > 1500

        guard moved || forecasts[old.id] == nil else { return }

        locations[index].latitude = latitude
        locations[index].longitude = longitude
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(newLocation).first {
            locations[index].name = placemark.locality ?? placemark.name ?? "Ubicación actual"
            locations[index].detail = ["Ubicación actual", placemark.country].compactMap { $0 }.joined(separator: " · ")
        }
        saveLocations()
        if selectedLocation?.id == old.id {
            await refresh()
        }
    }

    fileprivate func locationFailed(_ message: String) {
        if selectedLocation?.isCurrentLocation == true, forecast == nil {
            errorMessage = message
            onChange?()
        }
    }
}

extension WeatherStore: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat = last.coordinate.latitude
        let lon = last.coordinate.longitude
        Task { @MainActor in
            await WeatherStore.shared.updateCurrentLocation(latitude: lat, longitude: lon)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = "No se pudo obtener tu ubicación (\(error.localizedDescription)). Puedes añadir una ciudad en los ajustes."
        Task { @MainActor in
            WeatherStore.shared.locationFailed(message)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let store = WeatherStore.shared
            if store.locations.contains(where: \.isCurrentLocation),
               manager.authorizationStatus != .notDetermined {
                store.requestLocation()
            }
        }
    }
}
