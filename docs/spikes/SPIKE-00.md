# Spike 0 · Technical feasibility

**Date:** 2026-10-07 · **macOS:** 27.0.1 (26A434) · **Hardware:** Apple Silicon MacBook Pro, built-in display + external 1920×1080 display

**Recommendation: GO, full capability level.** Every capability Tabby needs works with public APIs plus `_AXUIElementGetWindow`. Moving windows to another desktop (H9) is still to be tested, and it does not block v0.1.

## How it was tested

`tabby-probe` (in `Packages/TabbyKit`) ran four times:

1. Guided run 1 (probe 0.1): invalid. A bug in the keyboard tap created a disable/re-enable loop that overloaded the WindowServer. Fixed in 0.2 by ignoring `tapDisabledByUserInput` and moving the tap to its own thread.
2. Guided run 2 (probe 0.2): detection and native keys.
3. Guided run 3 (probe 0.3): Mission Control exploration and hit-testing.
4. Automated run (`tabby-probe auto`, probe 0.4): 5 open/close cycles and 9 Tab + Return attempts with verification, no human input.

## Results

| ID | Hypothesis | Result |
|---|---|---|
| H0 | Native Mission Control keyboard behavior | Without the mouse, arrows, Tab and Return do nothing. Space only previews a hovered window. **The product premise holds.** |
| H1 | Detect Mission Control opening/closing | The `AXExpose*` notifications register but never fire, on both the Dock and the WindowManager. **While Mission Control is open, the Dock exposes `AXGroup id=mc` at its top level:** 5/5 opens and 5/5 closes detected, median 37 ms from the key press with 100 ms polling. ⌘Tab adds a second `AXList`, so detection must look for `mc`. |
| H2 | Window list during Mission Control | Pass. Same windows, in recency order, before and during Mission Control (snapshot ≈ 15 ms). |
| H3 | Thumbnail geometry | **Pass, through the WindowManager process** (`com.apple.WindowManager`), not the Dock. Structure: `AXGroup id=mc.display` per display → one `AXButton` per thumbnail with `id=<bundleID>.space.<n>`, the window title, its exact on-screen frame and `AXPress`. 6/6 windows matched across two displays. The tree contains duplicate buttons (same id, title and frame), so it must be de-duplicated. |
| H4 | Activate through the thumbnail (`AXPress`) | 2/3 exact. Mission Control closes itself with its native animation in ≈ 23 ms. One Finder attempt (two Finder windows) did not end on Finder: verify focus and fall back. |
| H5 | Activate through Accessibility / `NSRunningApplication` | 3/3 and 3/3 exact window, but **Mission Control stays open**, so Tabby has to close it afterwards. |
| H6 | Overlay above Mission Control | Pass. A non-activating `NSPanel` at the assistive-technology level (1500) stays above Mission Control's windows (Dock 20, WindowManager ≤ 19), and the user saw it. |
| H7 | Intercept Tab / Return inside Mission Control | Pass. 9/9 Tab sequences, 9/9 correct selections, 9/9 Return keys, 0 tap timeouts. Accessibility permission is enough (Input Monitoring was also granted). |
| H8 | `_AXUIElementGetWindow` | Pass. 100 % of the real windows matched; windows that exist only in the Window Server have no AX element and are ignored. |
| H9 | Move a window to another desktop | Pending. The Spaces bar is exposed: `mc.spaces` → `mc.spaces.list` → one `AXButton` per desktop ("Escritorio 1", "Escritorio 2", with `AXPress` and `AXRemoveDesktop`) plus `mc.spaces.add`, all with frames. Thumbnails expose no "move" action, so the synthetic drag still has to be tested. |
| H10 | Shortcut fallback | Not needed. |

## Decisions for the app

1. **Detection.** Poll the Dock's top-level AX children for `AXGroup id=mc` (one cheap call per tick). Measure CPU in Phase 3; if needed, poll slower while idle and faster around likely triggers.
2. **Thumbnails and highlight.** Read them from WindowManager (`MissionControlAccessibility`). De-duplicate, then match them to windows by bundle ID + title, falling back to aspect ratio. Draw the highlight on the thumbnail frame.
3. **Activation order.**
   - A: `AXPress` on the thumbnail, which gives the native animation. Then verify the focused window.
   - B, if A fails or focus is wrong: Accessibility (frontmost + main + raise), then close Mission Control with Esc.
4. **Keyboard.** Event tap on its own thread, consuming Tab / ⇧Tab / Return only while Mission Control is open. `tapDisabledByUserInput` is ignored.
5. **Overlay.** Non-activating `NSPanel`, `.stationary`, assistive-technology window level.

## Open items

- Re-check the Finder `AXPress` failure (duplicate buttons? slow activation?).
- Confirm focus is kept after closing Mission Control with Esc (strategy B).
- Measure the CPU cost of polling while idle.
- H9: synthetic drag from a thumbnail to a desktop button (Phase 2).
