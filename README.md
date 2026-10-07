# Tabby

Keyboard navigation for macOS Mission Control.

> **Status:** early development (technical feasibility spike). Not ready for daily use yet.

Tabby is a free and open-source macOS utility that lets you pick windows in Mission Control using only your keyboard. Open Mission Control the way you always do, press Tab to move between windows and Return to jump to one.

## Privacy

Tabby only listens to the keyboard while Mission Control is open. It never records or transmits keyboard input, and it has no network access.

## Development

- `Packages/TabbyKit`: core logic and `tabby-probe`, the diagnostic tool.
- Run the tests: `swift test --package-path Packages/TabbyKit`
- Run the probe: see [docs/spikes/README.md](docs/spikes/README.md).

## License

The code is released under the [MIT License](LICENSE). The Tabby name, logo and icon are not covered by the MIT License.
