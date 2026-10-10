<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp; <b>Español</b>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png">
    <img src="docs/assets/logo-light.png" alt="Tabby" width="440">
  </picture>
</p>

<h3 align="center">Navegación con teclado para Mission Control de macOS</h3>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-2EA44F">
  <img alt="Status: alpha" src="https://img.shields.io/badge/status-alpha-F59E0B">
</p>

<p align="center">
  <a href="../../releases/latest/download/Tabby.zip"><img alt="Descargar para macOS" src="https://img.shields.io/badge/macOS-Descargar%20Tabby-0A5CFF?style=for-the-badge&logo=apple&logoColor=white"></a>
  <br>
  <sub>Sin instalador: descarga el zip, abre Tabby.app y listo. Universal (Apple Silicon + Intel) · macOS 14+ · <a href="../../releases">todas las versiones</a></sub>
</p>

<!-- Video de demostración: arrastra el .mp4 a un comentario de cualquier issue o pull request de GitHub, copia la URL que genera y pégala aquí en una línea sola. GitHub lo muestra como reproductor. -->

---

> [!NOTE]
> Tabby está en alfa: funciona todos los días en la Mac de su autor, pero puede tener detalles. Los reportes de errores son muy bienvenidos.

## ¿Qué es Tabby?

Mission Control muestra todas tus ventanas abiertas de un vistazo, pero para elegir una todavía tienes que ir al mouse o al trackpad. **Tabby te permite hacerlo con el teclado**, igual que con ⌘Tab.

<p align="center">
  <kbd>⌃</kbd> <kbd>↑</kbd> &nbsp;➜&nbsp; <kbd>Tab</kbd> <kbd>Tab</kbd> &nbsp;➜&nbsp; <kbd>Enter ↩</kbd>
</p>

1. **Abre Mission Control** como siempre: atajo de teclado, F3, gesto del trackpad o esquina activa.
2. **Presiona <kbd>Tab</kbd>** para recorrer tus ventanas, empezando por la más reciente. <kbd>⇧</kbd> <kbd>Tab</kbd> vuelve atrás.
3. **Presiona <kbd>Enter ↩</kbd>**: Mission Control se cierra y esa ventana exacta pasa al frente.

Tabby no reemplaza Mission Control ni dibuja su propio selector: funciona encima del nativo.

## Funciones

| | |
|---|---|
| ⌨️ **Primero el teclado** | Tab, ⇧Tab y Enter dentro de Mission Control, empezando por la ventana más reciente. |
| 🎯 **La ventana exacta** | Enfoca la ventana que elegiste, aunque haya varias de la misma app. |
| ✨ **Sabes dónde estás** | La ventana seleccionada se levanta un poco con un resorte suave y vuelve a su lugar al pasar a otra. |
| 🗂️ **Mándala a un escritorio** | <kbd>⌘</kbd><kbd>1</kbd>…<kbd>⌘</kbd><kbd>9</kbd> mueve la ventana seleccionada a ese escritorio y, si todavía no existe, lo crea. |
| ⚙️ **Tus atajos** | Cambia cualquier atajo en **Settings**. |
| 🪄 **Como sea que lo abras** | Atajo, F3, gesto o esquina activa: Tabby no depende de ninguno. |
| 🍎 **Nativa** | Swift, SwiftUI y AppKit. Una app mínima en la barra de menús que no estorba. |
| 🔒 **Privada** | Sin analíticas y sin cuentas. Solo escucha el teclado mientras Mission Control está abierto, y lo único que consulta por red es si hay una versión nueva (opcional). |
| 💸 **Gratis y de código abierto** | Licencia MIT. |

## Hoja de ruta

- [x] **Spike 0:** validar las capacidades de macOS que necesita Tabby
- [x] **v0.1.0-alpha.1:** app de barra de menús con Tab, ⇧Tab y Enter, efecto de agrandar, escritorios y Configuración
- [ ] **v0.1.0:** primera versión estable
- [ ] Navegación con flechas según la posición de las miniaturas
- [x] Mover la ventana seleccionada a otro escritorio con un atajo
- [ ] Atajos numéricos (1–9) y búsqueda de ventanas

## Descarga

Tabby es una sola descarga, sin instalador. Usa el botón **Download** de arriba, o:

1. Descarga [**Tabby.zip**](../../releases/latest/download/Tabby.zip) de la última versión y ábrelo para descomprimir **Tabby.app**.
2. Arrastra **Tabby.app** a la carpeta **Aplicaciones**. También funciona desde Descargas, pero *Abrir al iniciar sesión* necesita que esté en Aplicaciones.
3. Abre **Tabby.app**.

### La primera vez, macOS la bloquea

Tabby es gratis y no está notarizada por Apple, porque eso requiere una cuenta paga de desarrollador. Por eso, la primera vez que la abres, macOS avisa que Apple no pudo verificar que Tabby no contenga software malicioso y ofrece mandarla a la papelera. Tabby es segura y su código es abierto, así que:

1. Haz clic en **Listo**. No la mandes a la papelera.
2. Abre **Configuración del Sistema → Privacidad y seguridad** y baja hasta **Seguridad**. Vas a ver *Se bloqueó "Tabby" para proteger tu Mac.*
3. Haz clic en **Abrir de todos modos**.
4. macOS vuelve a preguntar: haz clic en **Abrir de todos modos**.
5. Escribe tu contraseña o usa Touch ID. Si no aparece ningún pedido, mira tu otra pantalla: a veces se abre ahí.
6. **Si el ícono de Tabby no aparece en la barra de menús después de unos segundos, cierra la copia trabada y vuelve a abrir Tabby.** La copia que abriste antes de aprobar queda congelada, y macOS manda cada doble clic nuevo a esa copia. Abre el **Monitor de Actividad**, selecciona **Tabby**, haz clic en **ⓧ** → **Forzar salida**, y abre Tabby otra vez. Tu aprobación ya quedó guardada, así que esta vez arranca al instante. (Terminal: `pkill -9 Tabby; open ~/Downloads/Tabby.app`.)

Tabby se abre, su ícono aparece en la barra de menús y una bienvenida corta te guía con el permiso de **Accesibilidad** y una primera prueba. Esto se hace una sola vez, aunque una versión nueva descargada de internet puede volver a pedirlo.

### Si Tabby sigue sin abrir

- **No pasa nada después de «Abrir de todos modos»:** el pedido de contraseña o Touch ID puede estar esperando en otra pantalla o en otro escritorio. Abre Mission Control para encontrarlo.
- **Haces doble clic en Tabby y no pasa nada:** hay una copia trabada esperando esa aprobación. Fuérzala a salir como en el paso 6 y vuelve a abrir Tabby. Si macOS la vuelve a bloquear, repite los pasos de arriba una vez más.
- **No aparece «Abrir de todos modos»:** el botón solo está durante una hora, más o menos, después de que macOS bloquea Tabby. Vuelve a abrir Tabby para que macOS la bloquee y entra otra vez a **Privacidad y seguridad**.
- **Tienes varias copias de Tabby:** deja solo la de **Aplicaciones** y borra las demás, también el zip, así siempre abres la misma.

## Privacidad

macOS exige el permiso de Accesibilidad a las apps que detectan Mission Control, leen información de las ventanas y enfocan ventanas de otras apps. Tabby lo usa solo para eso:

- Solo escucha el teclado mientras Mission Control está abierto.
- Nunca guarda ni envía lo que escribes.
- No tiene analíticas ni cuentas. Lo único que hace por red es buscar versiones nuevas: al abrirse y cada 12 horas lee la última versión publicada en GitHub. No se envía nada sobre ti, y se puede desactivar en Settings.
- **Grabación de pantalla es opcional** y solo se usa para el efecto de agrandar. Tabby captura las ventanas de la pantalla actual mientras Mission Control está abierto, guarda las imágenes en memoria y las descarta al cerrarlo. No se guarda ni se envía nada. Sin ese permiso, Tabby funciona igual con un recuadro simple.
- El código es abierto: puedes comprobar todo lo anterior.

## Requisitos

macOS 14 Sonoma o posterior · Apple Silicon o Intel

## Desarrollo

```bash
swift test --package-path Packages/TabbyKit
scripts/build-app.sh
open build/Tabby.app
```

| Ruta | Qué es |
|---|---|
| `Packages/TabbyKit` | Lógica principal: detección de Mission Control, teclado, ventanas y navegación. |
| `TabbyApp` | La app de barra de menús, empaquetada por `scripts/build-app.sh`. |
| `tabby-probe` | Herramienta de diagnóstico guiada que comprueba qué permite tu versión de macOS. Ver [docs/spikes](docs/spikes/README.md). |

Las ideas, los issues y los pull requests son bienvenidos. Si algo no funciona, abre **Diagnostics…** en el menú, copia el reporte y pégalo en el issue.

## Apoya a Tabby

Tabby es gratis y de código abierto, hecho con ❤️ en Argentina 🇦🇷. Si te ahorra tiempo todos los días, puedes invitarme un café: cada aporte ayuda a sumar funciones y a mantener Tabby al día con cada macOS nuevo.

- Alias de **Mercado Pago** (Argentina): `cristiandjr.mp`
- **USDT** por la red Tron (TRC20), desde cualquier país: `TFUMsNxJGjum96MKHLfwabf8MTxpVuZLBx` — envía solo USDT por TRC20 a esta dirección.
- Dejar una ⭐ en el repo y compartir Tabby con alguien también ayuda muchísimo.

## Licencia

El código se publica bajo la [Licencia MIT](LICENSE). El nombre, el logo y el ícono de Tabby no están cubiertos por la Licencia MIT.
