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
| 🪄 **However you open it** | Shortcut, F3, trackpad gesture or hot corner: Tabby doesn't depend on any of them. |
| 🍎 **Native** | Swift, SwiftUI and AppKit. A tiny menu bar app that stays out of your way. |
| 🔒 **Private** | No network, no analytics, no accounts. It only listens to the keyboard while Mission Control is open. |
| 💸 **Free and open source** | MIT licensed. |

### Roadmap

- [ ] **Spike 0:** validate the macOS capabilities Tabby relies on *(in progress)*
- [ ] **v0.1:** menu bar app with Tab, ⇧Tab and Return
- [ ] Arrow-key navigation based on the thumbnails' positions
- [ ] Move the selected window to another desktop with a shortcut
- [ ] Number shortcuts (1–9) and window search

### Download

There is no release yet. When v0.1 is ready, Tabby will be a single download, with no installer:

1. Download **Tabby.zip** from [Releases](https://github.com/cristiandjr/tabby/releases) and open it.
2. Open **Tabby.app**. Tabby isn't notarized yet, so macOS blocks it the first time: go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. Grant **Accessibility** permission when asked.
4. Optional: move Tabby to **Applications**. You only need this for *Launch at Login*.

### Privacy

macOS requires Accessibility permission for apps that detect Mission Control, read window information and focus windows that belong to other apps. Tabby uses it for exactly that:

- It only listens to the keyboard while Mission Control is open.
- It never records or sends what you type.
- It has no network access, no analytics and no accounts.
- The code is open, so you can check all of the above.

### Requirements

macOS 14 Sonoma or later · Apple Silicon or Intel

### Development

```bash
swift test --package-path Packages/TabbyKit
swift build --package-path Packages/TabbyKit -c release
```

| Path | What it is |
|---|---|
| `Packages/TabbyKit` | Core logic: Mission Control detection, keyboard, windows and navigation. |
| `tabby-probe` | Guided diagnostic tool that checks what your macOS version allows. See [docs/spikes](docs/spikes/README.md). |

Ideas, issues and pull requests are welcome. If you like the project, a ⭐ helps a lot.

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
| 🪄 **Como sea que lo abras** | Atajo, F3, gesto o esquina activa: Tabby no depende de ninguno. |
| 🍎 **Nativa** | Swift, SwiftUI y AppKit. Una app mínima en la barra de menús que no estorba. |
| 🔒 **Privada** | Sin red, sin analíticas y sin cuentas. Solo escucha el teclado mientras Mission Control está abierto. |
| 💸 **Gratis y de código abierto** | Licencia MIT. |

### Hoja de ruta

- [ ] **Spike 0:** validar las capacidades de macOS que necesita Tabby *(en curso)*
- [ ] **v0.1:** app de barra de menús con Tab, ⇧Tab y Enter
- [ ] Navegación con flechas según la posición de las miniaturas
- [ ] Mover la ventana seleccionada a otro escritorio con un atajo
- [ ] Atajos numéricos (1–9) y búsqueda de ventanas

### Descarga

Todavía no hay versiones publicadas. Cuando esté lista la v0.1, Tabby será una sola descarga, sin instalador:

1. Descarga **Tabby.zip** desde [Releases](https://github.com/cristiandjr/tabby/releases) y ábrelo.
2. Abre **Tabby.app**. Como todavía no está notarizada, macOS la bloquea la primera vez: ve a **Configuración del Sistema → Privacidad y seguridad** y haz clic en **Abrir igualmente**.
3. Da el permiso de **Accesibilidad** cuando lo pida.
4. Opcional: mueve Tabby a **Aplicaciones**. Solo hace falta para *Abrir al iniciar sesión*.

### Privacidad

macOS exige el permiso de Accesibilidad a las apps que detectan Mission Control, leen información de las ventanas y enfocan ventanas de otras apps. Tabby lo usa solo para eso:

- Solo escucha el teclado mientras Mission Control está abierto.
- Nunca guarda ni envía lo que escribes.
- No tiene acceso a la red, ni analíticas, ni cuentas.
- El código es abierto: puedes comprobar todo lo anterior.

### Requisitos

macOS 14 Sonoma o posterior · Apple Silicon o Intel

### Desarrollo

```bash
swift test --package-path Packages/TabbyKit
swift build --package-path Packages/TabbyKit -c release
```

| Ruta | Qué es |
|---|---|
| `Packages/TabbyKit` | Lógica principal: detección de Mission Control, teclado, ventanas y navegación. |
| `tabby-probe` | Herramienta de diagnóstico guiada que comprueba qué permite tu versión de macOS. Ver [docs/spikes](docs/spikes/README.md). |

Las ideas, los issues y los pull requests son bienvenidos. Si te gusta el proyecto, una ⭐ ayuda muchísimo.

### Licencia

El código se publica bajo la [Licencia MIT](LICENSE). El nombre, el logo y el ícono de Tabby no están cubiertos por la Licencia MIT.
