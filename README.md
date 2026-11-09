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

Necesitas macOS 13 o posterior y las herramientas de línea de comandos de Xcode (`xcode-select --install`). No hace falta Xcode completo.

```bash
git clone https://github.com/davidcasanovasola-git/TiempoDock.git
cd TiempoDock
./scripts/install.sh
```

El script compila la app, la copia a `/Applications/TiempoDock.app` y la abre. La primera vez macOS te pedirá permiso para usar tu ubicación. Si no se lo das, añade una ciudad en **Ajustes › Ubicaciones**.

Para que se abra sola al encender el Mac: **Ajustes › General › Abrir TiempoDock al iniciar sesión**. Al iniciar sesión se abre **sin ventana**: solo aparece el icono del Dock. Conviene además fijarla en el Dock: clic derecho en el icono › Opciones › Mantener en el Dock.

Solo compilar, sin instalar: `./scripts/build.sh`, que deja la app en `build/TiempoDock.app`.

## Actualizaciones automáticas

La app comprueba [GitHub Releases](../../releases) al abrirse y cada 6 horas. Si hay una versión nueva, la descarga, comprueba que es TiempoDock con una firma válida, se reemplaza en `/Applications` y se vuelve a abrir. Si estaba sin ventana, sigue sin ventana. Se puede desactivar o forzar en **Ajustes › General › Actualizaciones**, o desde el menú **TiempoDock › Buscar actualizaciones…**.

Para publicar una versión nueva:

```bash
./scripts/release.sh 1.1.0
```

Eso crea y sube la etiqueta `v1.1.0`. El workflow `.github/workflows/release.yml` compila la app en GitHub Actions y la publica como `TiempoDock.zip` en un release nuevo.

> El repositorio tiene que ser **público** para que la app pueda leer los releases sin credenciales.

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

- La app se firma localmente (ad-hoc), así que funciona en el Mac donde la compilas. Para repartirla a otros Macs habría que firmarla y notarizarla con una cuenta de desarrollador de Apple.
- Cuando la app está cerrada, el Dock vuelve a mostrar el icono normal: el dato solo se dibuja mientras está abierta.

## Licencia

MIT. Mira [LICENSE](LICENSE).
