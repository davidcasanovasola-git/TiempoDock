import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = WeatherStore.shared
    private let statusItem = StatusItemController()
    private var forecastWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var launchedAsLoginItem = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            launchedAsLoginItem = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        NSApp.mainMenu = MenuBuilder.mainMenu()
        store.onChange = { [weak self] in self?.refreshUI() }
        refreshUI()
        store.start()
        if !launchedAsLoginItem {
            showForecast()
        }
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
        }
        present(forecastWindow)
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(
                title: "Ajustes de TiempoDock",
                autosave: "SettingsWindow",
                content: SettingsView().environmentObject(store),
                size: NSSize(width: 520, height: 500)
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
