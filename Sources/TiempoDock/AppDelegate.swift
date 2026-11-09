import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = WeatherStore.shared
    private let statusItem = StatusItemController()
    private var forecastWindow: NSWindow?
    private var settingsWindow: NSWindow?
    /// Al iniciar sesión (o tras actualizarse en segundo plano) la app arranca con
    /// `--background`: solo aparece el icono del Dock, sin abrir ventanas.
    private let launchedInBackground = CommandLine.arguments.contains("--background")

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        LoginItem.migrateIfNeeded()
        NSApp.mainMenu = MenuBuilder.mainMenu()
        store.onChange = { [weak self] in self?.refreshUI() }
        refreshUI()
        store.start()
        Updater.shared.start()
        if !launchedInBackground {
            showForecast()
        }
    }

    /// Hay alguna ventana de la app abierta en pantalla.
    var hasVisibleWindows: Bool {
        [forecastWindow, settingsWindow].contains { $0?.isVisible == true }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showForecast() }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        MenuBuilder.weatherMenu(store: store, forStatusBar: false)
    }

    private func refreshUI() {
        DockIconRenderer.update(store: store)
        statusItem.update(store: store)
    }

    // MARK: - Ventanas

    func showForecast() {
        if forecastWindow == nil {
            forecastWindow = makeWindow(
                title: "TiempoDock",
                autosave: "ForecastWindow",
                content: ForecastView().environmentObject(store),
                size: NSSize(width: 480, height: 740)
            )
            // La ventana de previsión se pinta con el cielo hasta arriba, bajo la barra de título.
            forecastWindow?.titlebarAppearsTransparent = true
            forecastWindow?.styleMask.insert(.fullSizeContentView)
            forecastWindow?.titleVisibility = .hidden
            forecastWindow?.appearance = NSAppearance(named: .darkAqua)
        }
        present(forecastWindow)
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(
                title: L("TiempoDock Settings"),
                autosave: "SettingsWindow",
                content: SettingsView().environmentObject(store),
                size: NSSize(width: 540, height: 600)
            )
            settingsWindow?.styleMask.remove(.resizable)
        }
        present(settingsWindow)
    }

    private func present(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow<V: View>(title: String, autosave: String, content: V, size: NSSize) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        window.center()
        window.setFrameAutosaveName(autosave)
        return window
    }
}
