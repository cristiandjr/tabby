# Spike 0 · tabby-probe

`tabby-probe` is a guided command-line test for the macOS capabilities Tabby relies on:

- Mission Control detection through the Dock accessibility notifications.
- The Dock accessibility tree while Mission Control is open.
- Keyboard interception while Mission Control is open.
- Window activation strategies.
- An overlay drawn above Mission Control.

It uses the real TabbyKit components, so whatever it validates becomes the base of the app. It also stays in the repository as a compatibility check for new macOS versions.

## Run

1. Open **Terminal.app**. Do not use an IDE terminal: macOS grants the permission to the app that launches the probe.
2. Give Terminal Accessibility permission: System Settings → Privacy & Security → Accessibility.
3. From the repository root:

```bash
swift build --package-path Packages/TabbyKit -c release
Packages/TabbyKit/.build/release/tabby-probe
```

| Command | What it does |
|---|---|
| `run` | Guided test (default, about 10 minutes) |
| `check` | Prints permissions and environment |
| `dump` | Saves the Dock accessibility tree while Mission Control is open |

Results are written to `probe-results/<timestamp>/` (`report.json`, `summary.md`, `dock-tree-*.txt`). They are not committed because they may contain window titles.

You can revoke Terminal's Accessibility permission when you are done.
