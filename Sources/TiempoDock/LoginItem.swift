import ServiceManagement

/// Arranque al iniciar sesión mediante un LaunchAgent incluido en la app
/// (Contents/Library/LaunchAgents). Así podemos pasarle `--background` y que
/// la app se abra sin ventana, solo con el icono del Dock.
enum LoginItem {
    static let service = SMAppService.agent(plistName: "io.github.tiempodock.agent.plist")

    static var isEnabled: Bool {
        service.status == .enabled || service.status == .requiresApproval
    }

    static var needsApproval: Bool {
        service.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    /// Las primeras versiones registraban la app entera como elemento de inicio;
    /// lo cambiamos por el agente que arranca en segundo plano.
    static func migrateIfNeeded() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
            try? service.register()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
