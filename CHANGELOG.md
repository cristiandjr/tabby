# Changelog

All notable changes to Tabby are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0-alpha.1] - 2026-10-07

First preview build.

### Added

- Menu bar app that works on top of macOS Mission Control.
- <kbd>Tab</kbd> / <kbd>⇧</kbd><kbd>Tab</kbd> move through the windows of the current display, most recent first. <kbd>Return</kbd> goes to the selected window, and <kbd>Esc</kbd> closes Mission Control as usual.
- A highlight drawn on the selected Mission Control thumbnail, plus a bar with the window name.
- Works however you open Mission Control: keyboard shortcut, F3, trackpad gesture or hot corner.
- Moving the mouse hands the selection back to Mission Control's own hover highlight.
- Pause toggle and Launch at Login in the menu.

### Known issues

- Not notarized yet. The first time, macOS blocks it: open System Settings → Privacy & Security → Open Anyway.
- Shortcuts are not configurable yet.
