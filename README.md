# TiempoDock

El tiempo **en el icono del Dock** de tu Mac. Gratis, de código abierto y sin anuncios.

El icono muestra el estado del cielo y la temperatura y se actualiza solo. Con un clic se abre la previsión completa y con clic derecho tienes un resumen rápido.

## Funciones

- **Icono del Dock en directo**: símbolo del tiempo, fondo que cambia según el cielo (día, noche, nubes, lluvia, tormenta, nieve, niebla) y el dato que elijas:
  - temperatura actual, sensación térmica, viento, humedad,
  - máxima/mínima de hoy o de mañana,
  - probabilidad de lluvia de hoy.
- **Clic derecho en el Dock**: tiempo actual, próximas horas, próximos 5 días, cambio de ubicación y actualizar.
- **Ventana de previsión**: condiciones actuales (sensación, humedad, viento con dirección, precipitación, amanecer y atardecer), las próximas 24 horas y hasta 16 días.
- **Varias ubicaciones**: tu ubicación actual (por GPS/wifi) y todas las ciudades que quieras, con buscador.
- **Unidades**: °C o °F; km/h, m/s, mph o nudos.
- **Barra de menús opcional** con la temperatura.
- **Actualización automática** cada 5, 10, 15, 30 o 60 minutos y al despertar el Mac.
- **Abrir al iniciar sesión**, sin ventana (solo el icono del Dock).
- **Actualizaciones automáticas** desde GitHub Releases.

Los datos vienen de [Open-Meteo](https://open-meteo.com) (licencia CC BY 4.0). Es gratuito y no necesita cuenta ni clave de API.

## Instalación

Funciona en macOS 13 Ventura o posterior, en Macs con chip Apple y con Intel. Abre la app **Terminal** y pega:

```bash
curl -fsSL https://raw.githubusercontent.com/davidcasanovasola-git/TiempoDock/main/scripts/get.sh | bash
```

Esto descarga la última versión, comprueba su suma SHA-256, la copia a Aplicaciones y la abre. No hace falta Xcode ni compilar nada, y macOS no muestra avisos. Puedes leer antes el script: [`scripts/get.sh`](scripts/get.sh).

La primera vez macOS te pedirá permiso para usar tu ubicación. Si no se lo das, o tu Mac no tiene localización, añade tu ciudad en **Ajustes › Ubicaciones**.

Para que se abra sola al encender el Mac: **Ajustes › General › Abrir TiempoDock al iniciar sesión**. Al iniciar sesión se abre **sin ventana**: solo aparece el icono del Dock. Conviene además fijarla en el Dock: clic derecho en el icono › Opciones › Mantener en el Dock.

### Si descargas el zip desde el navegador

TiempoDock es gratuito y de código abierto, y no está firmado con un certificado de pago de Apple. Por eso, si descargas `TiempoDock.zip` desde la página de Releases con el navegador, macOS lo bloqueará la primera vez. Para abrirlo:

1. Arrastra `TiempoDock.app` a Aplicaciones e intenta abrirla.
2. Ve a **Ajustes del Sistema › Privacidad y seguridad** y pulsa **Abrir igualmente**.

O, en Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/TiempoDock.app
```

Con el instalador de una línea no hace falta nada de esto.

### Compilar desde el código

Necesitas las herramientas de línea de comandos de Xcode (`xcode-select --install`). No hace falta Xcode completo.

```bash
git clone https://github.com/davidcasanovasola-git/TiempoDock.git
cd TiempoDock
./scripts/install.sh
```

Solo compilar, sin instalar: `./scripts/build.sh`, que deja la app universal en `build/TiempoDock.app`.

## Actualizaciones automáticas

La app comprueba [GitHub Releases](https://github.com/davidcasanovasola-git/TiempoDock/releases) al abrirse y cada 6 horas. Si hay una versión nueva:

1. Descarga `TiempoDock.zip`.
2. Comprueba que su suma SHA-256 coincide con `TiempoDock.zip.sha256`.
3. Comprueba que GitHub tiene una **certificación de origen** para ese archivo exacto, es decir, que lo generó el workflow oficial de este repositorio a partir de su código. Si no, no instala nada.
4. Comprueba que es TiempoDock y que su firma es válida, se reemplaza y se vuelve a abrir. Si estaba sin ventana, sigue sin ventana.

Se puede desactivar o forzar en **Ajustes › General › Actualizaciones**, o desde el menú **TiempoDock › Buscar actualizaciones…**.

Cualquiera puede comprobar a mano el origen de un zip con:

```bash
gh attestation verify TiempoDock.zip --repo davidcasanovasola-git/TiempoDock
```

### Publicar una versión nueva

```bash
./scripts/release.sh 1.2.0
```

Eso crea y sube la etiqueta `v1.2.0`. El workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) compila la app universal, calcula la suma, genera la certificación de origen y publica el release.

## Estructura

| Archivo | Qué hace |
| --- | --- |
| `Sources/TiempoDock/main.swift` | Arranque de la app |
| `AppDelegate.swift` | Ventanas, menú del Dock, ciclo de vida |
| `WeatherStore.swift` | Ubicaciones, previsiones, temporizador, ubicación actual |
| `WeatherService.swift` | Cliente de Open-Meteo (previsión y buscador de ciudades) |
| `DockIcon.swift` | Dibujo del icono del Dock |
| `ForecastView.swift` | Ventana de previsión |
| `SettingsView.swift` | Ajustes |
| `Menus.swift` | Menú del Dock, barra de menús y menú principal |
| `WeatherCode.swift` | Códigos de tiempo WMO → texto e icono |
| `Updater.swift` | Actualizaciones automáticas desde GitHub Releases |
| `LoginItem.swift` | Arranque al iniciar sesión (sin ventana) |

## Notas

- La app lleva una firma local (ad-hoc), no un certificado de pago de Apple. La integridad y el origen de cada versión se garantizan con la suma SHA-256 y la certificación de origen de GitHub.
- Con cada actualización macOS puede volver a pedir el permiso de ubicación, porque la firma local cambia de una versión a otra.
- Cuando la app está cerrada, el Dock vuelve a mostrar el icono normal: el dato solo se dibuja mientras está abierta.

## Licencia

MIT. Mira [LICENSE](LICENSE).
