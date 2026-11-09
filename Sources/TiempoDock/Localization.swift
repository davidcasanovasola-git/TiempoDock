import Foundation

/// Texto traducido al idioma del sistema.
///
/// Las claves son los textos en inglés; las traducciones están en
/// `Resources/Localization/<idioma>.lproj/Localizable.strings` y el script de
/// compilación las copia dentro de la app. Si falta una traducción, se muestra
/// el texto en inglés.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Igual que `L(_:)`, con valores para los `%@` / `%d` del texto.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: AppLocale.current, arguments: args)
}

enum AppLocale {
    /// Idioma en el que macOS ha elegido mostrar la app (según las traducciones
    /// incluidas y las preferencias del usuario). Se usa también para fechas.
    static let current = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
}
