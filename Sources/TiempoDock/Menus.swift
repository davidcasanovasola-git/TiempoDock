import AppKit

/// Destino de las acciones de los menús (Dock y barra de menús).
@MainActor
final class MenuActions: NSObject {
    static let shared = MenuActions()

    @objc func refresh() {
        Task { await WeatherStore.shared.refresh() }
    }

    @objc func openForecast() {
        (NSApp.delegate as? AppDelegate)?.showForecast()
    }

    @objc func openSettings() {
        (NSApp.delegate as? AppDelegate)?.showSettings()
    }

    @objc func selectLocation(_ sender: NSMenuItem) {
        if let s = sender.representedObject as? String, let id = UUID(uuidString: s) {
            WeatherStore.shared.select(id)
        }
    }

    @objc func checkForUpdates() {
        Task { await Updater.shared.check(userInitiated: true) }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
enum MenuBuilder {
    /// Menú con el resumen del tiempo. Se usa en el clic derecho del Dock y en la barra de menús.
    static func weatherMenu(store: WeatherStore, forStatusBar: Bool) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let actions = MenuActions.shared

        func item(_ title: String, symbol: String? = nil, action: Selector? = #selector(MenuActions.openForecast)) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
            i.target = actions
            if let symbol { i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            menu.addItem(i)
            return i
        }

        func header(_ title: String) {
            let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(i)
        }

        if let loc = store.selectedLocation, let f = store.forecast {
            let now = WeatherCode.info(f.current.code, isDay: f.current.isDay)
            _ = item("\(loc.name): \(Format.deg(f.current.temperature)), \(now.description.lowercased())", symbol: now.symbol)
            if let today = f.today {
                _ = item("Máx \(Format.deg(today.max)) · Mín \(Format.deg(today.min)) · Sensación \(Format.deg(f.current.feelsLike))", symbol: "thermometer.medium")
            }
            _ = item("Viento \(Format.int(f.current.windSpeed)) \(f.windUnit.symbol) \(Format.compass(f.current.windDirection)) · Humedad \(Format.int(f.current.humidity))%", symbol: "wind")

            menu.addItem(.separator())
            header("Próximas horas")
            let hours = f.upcomingHours
            for index in stride(from: 1, to: min(hours.count, 13), by: 2) {
                let h = hours[index]
                let info = WeatherCode.info(h.code, isDay: h.isDay)
                var title = "\(Format.time(h.time, in: f.timeZone))   \(Format.deg(h.temperature))"
                if let p = h.precipitationChance, p >= 10 { title += "   💧\(p)%" }
                _ = item(title, symbol: info.symbol)
            }

            menu.addItem(.separator())
            header("Próximos días")
            for (index, d) in f.days.prefix(5).enumerated() {
                let info = WeatherCode.info(d.code, isDay: true)
                var title = "\(Format.dayName(d.date, index: index, in: f.timeZone))   \(Format.deg(d.max)) / \(Format.deg(d.min))"
                if let p = d.precipitationChance, p >= 10 { title += "   💧\(p)%" }
                _ = item(title, symbol: info.symbol)
            }
            menu.addItem(.separator())
        } else {
            header(store.errorMessage ?? "Cargando el tiempo…")
            menu.addItem(.separator())
        }

        if store.locations.count > 1 {
            let parent = NSMenuItem(title: "Ubicación", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for loc in store.locations {
                let i = NSMenuItem(title: loc.name, action: #selector(MenuActions.selectLocation(_:)), keyEquivalent: "")
                i.target = actions
                i.representedObject = loc.id.uuidString
                i.state = loc.id == store.selectedLocation?.id ? .on : .off
                sub.addItem(i)
            }
            parent.submenu = sub
            menu.addItem(parent)
        }

        _ = item("Actualizar ahora", symbol: "arrow.clockwise", action: #selector(MenuActions.refresh))
        _ = item("Abrir previsión…", symbol: "calendar", action: #selector(MenuActions.openForecast))
        _ = item("Ajustes…", symbol: "gearshape", action: #selector(MenuActions.openSettings))

        if forStatusBar {
            menu.addItem(.separator())
            _ = item("Salir de TiempoDock", action: #selector(MenuActions.quit))
        }
        return menu
    }

    /// Barra de menús principal de la app.
    static func mainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Acerca de TiempoDock", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let updates = NSMenuItem(title: "Buscar actualizaciones…", action: #selector(MenuActions.checkForUpdates), keyEquivalent: "")
        updates.target = MenuActions.shared
        appMenu.addItem(updates)
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Ajustes…", action: #selector(MenuActions.openSettings), keyEquivalent: ",")
        settings.target = MenuActions.shared
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ocultar TiempoDock", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Ocultar otros", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Mostrar todo", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Salir de TiempoDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edición")
        editMenu.addItem(withTitle: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Rehacer", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let weatherItem = NSMenuItem()
        let weatherMenu = NSMenu(title: "Tiempo")
        let refresh = NSMenuItem(title: "Actualizar ahora", action: #selector(MenuActions.refresh), keyEquivalent: "r")
        refresh.target = MenuActions.shared
        weatherMenu.addItem(refresh)
        let open = NSMenuItem(title: "Abrir previsión", action: #selector(MenuActions.openForecast), keyEquivalent: "1")
        open.target = MenuActions.shared
        weatherMenu.addItem(open)
        weatherItem.submenu = weatherMenu
        main.addItem(weatherItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Ventana")
        windowMenu.addItem(withTitle: "Cerrar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        return main
    }
}

/// Icono opcional en la barra de menús.
@MainActor
final class StatusItemController {
    private var item: NSStatusItem?

    func update(store: WeatherStore) {
        let show = UserDefaults.standard.bool(forKey: Prefs.showMenuBar)
        if show, item == nil {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        } else if !show, let existing = item {
            NSStatusBar.system.removeStatusItem(existing)
            item = nil
        }
        guard let item, let button = item.button else { return }

        if let f = store.forecast {
            let info = WeatherCode.info(f.current.code, isDay: f.current.isDay)
            button.image = NSImage(systemSymbolName: info.symbol, accessibilityDescription: info.description)
            button.title = " " + Format.deg(f.current.temperature)
        } else {
            button.image = NSImage(systemSymbolName: "cloud.sun", accessibilityDescription: nil)
            button.title = " --°"
        }
        button.imagePosition = .imageLeading
        item.menu = MenuBuilder.weatherMenu(store: store, forStatusBar: true)
    }
}
