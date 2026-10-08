<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png">
    <img src="docs/assets/logo-light.png" alt="Tabby" width="440">
  </picture>
</p>

<h3 align="center">Keyboard navigation for macOS Mission Control</h3>
<p align="center"><em>Navegación con teclado para Mission Control de macOS</em></p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-2EA44F">
  <img alt="Status: early development" src="https://img.shields.io/badge/status-early%20development-F59E0B">
</p>

<p align="center">
  <a href="#english">English</a> &nbsp;·&nbsp; <a href="#espanol">Español</a>
</p>

---

<a id="english"></a>

## English

> [!NOTE]
> Tabby is in early development and not ready for daily use yet.

### What is Tabby?

Mission Control shows all your open windows at a glance, but choosing one still means reaching for the mouse or the trackpad. **Tabby lets you do it with the keyboard**, the same way you use ⌘Tab.

<p align="center">
  <kbd>⌃</kbd> <kbd>↑</kbd> &nbsp;➜&nbsp; <kbd>Tab</kbd> <kbd>Tab</kbd> &nbsp;➜&nbsp; <kbd>Return ↩</kbd>
</p>

1. **Open Mission Control** the way you always do: keyboard shortcut, F3, trackpad gesture or hot corner.
2. **Press <kbd>Tab</kbd>** to move through your windows, most recent first. <kbd>⇧</kbd> <kbd>Tab</kbd> goes back.
3. **Press <kbd>Return ↩</kbd>**: Mission Control closes and that exact window comes to the front.

Tabby doesn't replace Mission Control or draw its own switcher. It works on top of the native one.

### Features

| | |
|---|---|
| ⌨️ **Keyboard first** | Tab, ⇧Tab and Return inside Mission Control, most recent window first. |
| 🎯 **The exact window** | Focuses the window you picked, even when several windows belong to the same app. |
| ✨ **See where you are** | The selected window lifts slightly with a soft spring and settles back when you move on. |
| 🗂️ **Send it to a desktop** | <kbd>⌘</kbd><kbd>1</kbd>…<kbd>⌘</kbd><kbd>9</kbd> moves the selected window to that desktop, creating it if it doesn't exist yet. |
| ⚙️ **Your shortcuts** | Change every shortcut in Settings. |
| 🪄 **However you open it** | Shortcut, F3, trackpad gesture or hot corner: Tabby doesn't depend on any of them. |
| 🍎 **Native** | Swift, SwiftUI and AppKit. A tiny menu bar app that stays out of your way. |
| 🔒 **Private** | No network, no analytics, no accounts. It only listens to the keyboard while Mission Control is open. |
| 💸 **Free and open source** | MIT licensed. |

### Roadmap

- [x] **Spike 0:** validate the macOS capabilities Tabby relies on
- [x] **v0.1.0-alpha.1:** menu bar app with Tab, ⇧Tab and Return, lift effect, desktops and Settings
- [ ] **v0.1.0:** first stable release
- [ ] Arrow-key navigation based on the thumbnails' positions
- [x] Move the selected window to another desktop with a shortcut
- [ ] Number shortcuts (1–9) and window search

### Download

Tabby is a single download, with no installer. The first preview is **v0.1.0-alpha.1**:

1. Download **Tabby.zip** from the [latest release](https://github.com/cristiandjr/tabby/releases) and open it.
2. Open **Tabby.app**. Tabby isn't notarized yet, so macOS blocks it the first time: go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. A short welcome tour guides you through the **Accessibility** permission and a first try.
4. Optional: move Tabby to **Applications**. You only need this for *Launch at Login*.

### Privacy

macOS requires Accessibility permission for apps that detect Mission Control, read window information and focus windows that belong to other apps. Tabby uses it for exactly that:

- It only listens to the keyboard while Mission Control is open.
- It never records or sends what you type.
- It has no network access, no analytics and no accounts.
- **Screen Recording is optional** and only powers the lift effect. Tabby captures the windows of the current display while Mission Control is open, keeps the images in memory and drops them when it closes. Nothing is saved or sent. Without it, Tabby works the same with a plain highlight.
- The code is open, so you can check all of the above.

### Requirements

macOS 14 Sonoma or later · Apple Silicon or Intel

### Development

```bash
swift test --package-path Packages/TabbyKit
scripts/build-app.sh
open build/Tabby.app
```

| Path | What it is |
|---|---|
| `Packages/TabbyKit` | Core logic: Mission Control detection, keyboard, windows and navigation. |
| `TabbyApp` | The menu bar app, bundled by `scripts/build-app.sh`. |
| `tabby-probe` | Guided diagnostic tool that checks what your macOS version allows. See [docs/spikes](docs/spikes/README.md). |

Ideas, issues and pull requests are welcome. If something doesn't work, open **Diagnostics…** in the menu, copy the report and paste it in the issue.

### Support Tabby

Tabby is free and open source, made with ❤️ in Argentina 🇦🇷. If it saves you time every day, you can buy me a coffee: every contribution helps add features and keep Tabby up to date with each new macOS.

- **Mercado Pago** alias: `cristiandjr.mp`
- Starring the repo ⭐ and sharing Tabby with a friend helps a lot too.

### License

The code is released under the [MIT License](LICENSE). The Tabby name, logo and icon are not covered by the MIT License.

---

<a id="espanol"></a>

## Español

> [!NOTE]
> Tabby está en desarrollo temprano y todavía no está listo para el uso diario.

### ¿Qué es Tabby?

Mission Control muestra todas tus ventanas abiertas de un vistazo, pero para elegir una todavía tienes que ir al mouse o al trackpad. **Tabby te permite hacerlo con el teclado**, igual que con ⌘Tab.

<p align="center">
  <kbd>⌃</kbd> <kbd>↑</kbd> &nbsp;➜&nbsp; <kbd>Tab</kbd> <kbd>Tab</kbd> &nbsp;➜&nbsp; <kbd>Enter ↩</kbd>
</p>

1. **Abre Mission Control** como siempre: atajo de teclado, F3, gesto del trackpad o esquina activa.
2. **Presiona <kbd>Tab</kbd>** para recorrer tus ventanas, empezando por la más reciente. <kbd>⇧</kbd> <kbd>Tab</kbd> vuelve atrás.
3. **Presiona <kbd>Enter ↩</kbd>**: Mission Control se cierra y esa ventana exacta pasa al frente.

Tabby no reemplaza Mission Control ni dibuja su propio selector: funciona encima del nativo.

### Funciones

| | |
|---|---|
| ⌨️ **Primero el teclado** | Tab, ⇧Tab y Enter dentro de Mission Control, empezando por la ventana más reciente. |
| 🎯 **La ventana exacta** | Enfoca la ventana que elegiste, aunque haya varias de la misma app. |
| ✨ **Sabes dónde estás** | La ventana seleccionada se levanta un poco con un resorte suave y vuelve a su lugar al pasar a otra. |
| 🗂️ **Mándala a un escritorio** | <kbd>⌘</kbd><kbd>1</kbd>…<kbd>⌘</kbd><kbd>9</kbd> mueve la ventana seleccionada a ese escritorio y, si todavía no existe, lo crea. |
| ⚙️ **Tus atajos** | Cambia cualquier atajo en **Settings**. |
| 🪄 **Como sea que lo abras** | Atajo, F3, gesto o esquina activa: Tabby no depende de ninguno. |
| 🍎 **Nativa** | Swift, SwiftUI y AppKit. Una app mínima en la barra de menús que no estorba. |
| 🔒 **Privada** | Sin red, sin analíticas y sin cuentas. Solo escucha el teclado mientras Mission Control está abierto. |
| 💸 **Gratis y de código abierto** | Licencia MIT. |

### Hoja de ruta

- [x] **Spike 0:** validar las capacidades de macOS que necesita Tabby
- [x] **v0.1.0-alpha.1:** app de barra de menús con Tab, ⇧Tab y Enter, efecto de agrandar, escritorios y Configuración
- [ ] **v0.1.0:** primera versión estable
- [ ] Navegación con flechas según la posición de las miniaturas
- [x] Mover la ventana seleccionada a otro escritorio con un atajo
- [ ] Atajos numéricos (1–9) y búsqueda de ventanas

### Descarga

Tabby es una sola descarga, sin instalador. La primera versión de prueba es la **v0.1.0-alpha.1**:

1. Descarga **Tabby.zip** desde la [última versión](https://github.com/cristiandjr/tabby/releases) y ábrelo.
2. Abre **Tabby.app**. Como todavía no está notarizada, macOS la bloquea la primera vez: ve a **Configuración del Sistema → Privacidad y seguridad** y haz clic en **Abrir igualmente**.
3. Una bienvenida corta te guía con el permiso de **Accesibilidad** y una primera prueba.
4. Opcional: mueve Tabby a **Aplicaciones**. Solo hace falta para *Abrir al iniciar sesión*.

### Privacidad

macOS exige el permiso de Accesibilidad a las apps que detectan Mission Control, leen información de las ventanas y enfocan ventanas de otras apps. Tabby lo usa solo para eso:

- Solo escucha el teclado mientras Mission Control está abierto.
- Nunca guarda ni envía lo que escribes.
- No tiene acceso a la red, ni analíticas, ni cuentas.
- **Grabación de pantalla es opcional** y solo se usa para el efecto de agrandar. Tabby captura las ventanas de la pantalla actual mientras Mission Control está abierto, guarda las imágenes en memoria y las descarta al cerrarlo. No se guarda ni se envía nada. Sin ese permiso, Tabby funciona igual con un recuadro simple.
- El código es abierto: puedes comprobar todo lo anterior.

### Requisitos

macOS 14 Sonoma o posterior · Apple Silicon o Intel

### Desarrollo

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

### Apoya a Tabby

Tabby es gratis y de código abierto, hecho con ❤️ en Argentina 🇦🇷. Si te ahorra tiempo todos los días, puedes invitarme un café: cada aporte ayuda a sumar funciones y a mantener Tabby al día con cada macOS nuevo.

- Alias de **Mercado Pago**: `cristiandjr.mp`
- Dejar una ⭐ en el repo y compartir Tabby con alguien también ayuda muchísimo.

### Licencia

El código se publica bajo la [Licencia MIT](LICENSE). El nombre, el logo y el ícono de Tabby no están cubiertos por la Licencia MIT.
