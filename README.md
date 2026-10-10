<p align="center">
  <b>English</b> &nbsp;·&nbsp; <a href="README.es.md">Español</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png">
    <img src="docs/assets/logo-light.png" alt="Tabby" width="440">
  </picture>
</p>

<h3 align="center">Keyboard navigation for macOS Mission Control</h3>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-2EA44F">
  <img alt="Status: alpha" src="https://img.shields.io/badge/status-alpha-F59E0B">
</p>

<p align="center">
  <a href="../../releases/latest/download/Tabby.zip"><img alt="Download for macOS" src="https://img.shields.io/badge/macOS-Download%20Tabby-0A5CFF?style=for-the-badge&logo=apple&logoColor=white"></a>
  <br>
  <sub>No installer: download the zip, open Tabby.app, done. Universal (Apple Silicon + Intel) · macOS 14+ · <a href="../../releases">all releases</a></sub>
</p>

<!-- Demo video: drag the .mp4 into any GitHub issue or pull request comment, copy the URL GitHub generates and paste it here on its own line. GitHub renders it as a player. -->

---

> [!NOTE]
> Tabby is in alpha: it works every day on the author's Mac, but expect rough edges. Bug reports are very welcome.

## What is Tabby?

Mission Control shows all your open windows at a glance, but choosing one still means reaching for the mouse or the trackpad. **Tabby lets you do it with the keyboard**, the same way you use ⌘Tab.

<p align="center">
  <kbd>⌃</kbd> <kbd>↑</kbd> &nbsp;➜&nbsp; <kbd>Tab</kbd> <kbd>Tab</kbd> &nbsp;➜&nbsp; <kbd>Return ↩</kbd>
</p>

1. **Open Mission Control** the way you always do: keyboard shortcut, F3, trackpad gesture or hot corner.
2. **Press <kbd>Tab</kbd>** to move through your windows, most recent first. <kbd>⇧</kbd> <kbd>Tab</kbd> goes back.
3. **Press <kbd>Return ↩</kbd>**: Mission Control closes and that exact window comes to the front.

Tabby doesn't replace Mission Control or draw its own switcher. It works on top of the native one.

## Features

| | |
|---|---|
| ⌨️ **Keyboard first** | Tab, ⇧Tab and Return inside Mission Control, most recent window first. |
| 🎯 **The exact window** | Focuses the window you picked, even when several windows belong to the same app. |
| ✨ **See where you are** | The selected window lifts slightly with a soft spring and settles back when you move on. |
| 🗂️ **Send it to a desktop** | <kbd>⌘</kbd><kbd>1</kbd>…<kbd>⌘</kbd><kbd>9</kbd> moves the selected window to that desktop, creating it if it doesn't exist yet. |
| ⚙️ **Your shortcuts** | Change every shortcut in Settings. |
| 🪄 **However you open it** | Shortcut, F3, trackpad gesture or hot corner: Tabby doesn't depend on any of them. |
| 🍎 **Native** | Swift, SwiftUI and AppKit. A tiny menu bar app that stays out of your way. |
| 🔒 **Private** | No analytics, no accounts. It only listens to the keyboard while Mission Control is open, and its only network request is the optional check for new versions. |
| 💸 **Free and open source** | MIT licensed. |

## Roadmap

- [x] **Spike 0:** validate the macOS capabilities Tabby relies on
- [x] **v0.1.0-alpha.1:** menu bar app with Tab, ⇧Tab and Return, lift effect, desktops and Settings
- [ ] **v0.1.0:** first stable release
- [ ] Arrow-key navigation based on the thumbnails' positions
- [x] Move the selected window to another desktop with a shortcut
- [ ] Number shortcuts (1–9) and window search

## Download

Tabby is a single download, with no installer. Use the **Download** button at the top, or:

1. Download [**Tabby.zip**](../../releases/latest/download/Tabby.zip) from the latest release and open it to unzip **Tabby.app**.
2. Drag **Tabby.app** to your **Applications** folder. It also runs from Downloads, but *Launch at Login* needs it in Applications.
3. Open **Tabby.app**.

### The first time macOS blocks it

Tabby is free and isn't notarized by Apple, which requires a paid developer account. So the first time you open it, macOS says that Apple could not verify that Tabby is free of malware, and offers to move it to the Trash. Tabby is safe and its code is open, so:

1. Click **Done**. Don't move it to the Trash.
2. Open **System Settings → Privacy & Security** and scroll down to **Security**. You'll see *"Tabby" was blocked to protect your Mac.*
3. Click **Open Anyway**.
4. macOS asks again: click **Open Anyway**.
5. Enter your password or use Touch ID. If no prompt shows up, check your other display: it sometimes opens there.
6. **If Tabby's icon doesn't appear in the menu bar after a few seconds, quit the stuck copy and open Tabby again.** The copy you opened before approving stays frozen, and macOS keeps sending every new double-click to it. Open **Activity Monitor**, select **Tabby**, click **ⓧ** → **Force Quit**, and open Tabby again. Your approval is already saved, so this time it starts right away. (Terminal: `pkill -9 Tabby; open ~/Downloads/Tabby.app`.)

Tabby opens, its icon appears in the menu bar, and a short welcome tour guides you through the **Accessibility** permission and a first try. You only do this once, although a new version downloaded from the internet may ask again.

### If Tabby still doesn't open

- **Nothing happens after Open Anyway:** the password or Touch ID request may be waiting on another display or on another desktop. Open Mission Control to find it.
- **Double-clicking Tabby does nothing:** a copy is stuck waiting for that approval. Force quit it as in step 6 and open Tabby again. If macOS blocks it again, go through the steps above once more.
- **There's no Open Anyway button:** it's only there for about an hour after macOS blocks Tabby. Open Tabby again so that macOS blocks it, and go back to **Privacy & Security**.
- **You have several copies of Tabby:** keep only the one in **Applications** and delete the rest, including the zip, so you always open the same one.

## Privacy

macOS requires Accessibility permission for apps that detect Mission Control, read window information and focus windows that belong to other apps. Tabby uses it for exactly that:

- It only listens to the keyboard while Mission Control is open.
- It never records or sends what you type.
- It has no analytics and no accounts. Its only network request is a check for new versions: when it starts and every 12 hours it reads the latest release from GitHub. Nothing about you is sent, and you can turn it off in Settings.
- **Screen Recording is optional** and only powers the lift effect. Tabby captures the windows of the current display while Mission Control is open, keeps the images in memory and drops them when it closes. Nothing is saved or sent. Without it, Tabby works the same with a plain highlight.
- The code is open, so you can check all of the above.

## Requirements

macOS 14 Sonoma or later · Apple Silicon or Intel

## Development

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

## Support Tabby

Tabby is free and open source, made with ❤️ in Argentina 🇦🇷. If it saves you time every day, you can buy me a coffee: every contribution helps add features and keep Tabby up to date with each new macOS.

- **Mercado Pago** alias (Argentina): `cristiandjr.mp`
- **USDT** on the Tron (TRC20) network, from anywhere in the world: `TFUMsNxJGjum96MKHLfwabf8MTxpVuZLBx` — send only USDT on TRC20 to this address.
- Starring the repo ⭐ and sharing Tabby with a friend helps a lot too.

## License

The code is released under the [MIT License](LICENSE). The Tabby name, logo and icon are not covered by the MIT License.
