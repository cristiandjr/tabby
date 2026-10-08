# Changelog

All notable changes to Tabby are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0-alpha.1] - 2026-10-07

First preview build.

### Added

- Menu bar app that works on top of macOS Mission Control.
- <kbd>Tab</kbd> / <kbd>⇧</kbd><kbd>Tab</kbd> move through the windows of the current display, most recent first. <kbd>Return</kbd> goes to the selected window, and <kbd>Esc</kbd> closes Mission Control as usual.
- A highlight drawn on the selected Mission Control thumbnail, plus a bar with the window name. It follows the exact size and position of each thumbnail, however many windows are open.
- Optional lift effect: the selected window grows slightly with a soft spring and settles back when you move on. It needs Screen Recording permission, which you can grant from the menu; without it you get the plain highlight.
- <kbd>⌘</kbd><kbd>1</kbd>…<kbd>⌘</kbd><kbd>9</kbd> inside Mission Control sends the selected window to that desktop of the current display. Missing desktops are created up to that number, and Mission Control stays open so you can keep sorting.
- Works however you open Mission Control: keyboard shortcut, F3, trackpad gesture or hot corner.
- Moving the mouse hands the selection back to Mission Control's own hover highlight.
- Pause, Lift the Selected Window and Launch at Login toggles in the menu.

### Known issues

- Not notarized yet. The first time, macOS blocks it: open System Settings → Privacy & Security → Open Anyway.
- Shortcuts are not configurable yet.
- Moving a window takes about a second: Tabby drags the thumbnail for you and puts the pointer back. Don't move the mouse meanwhile.
- Fullscreen apps in the desktops bar may shift the desktop numbers.
