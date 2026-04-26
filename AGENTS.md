# mu

A macOS-native GUI text editor optimized for instant startup.

## Architecture

Single-file Swift application (`Sources/main.swift`, ~150 lines) using AppKit directly — no SwiftUI, no .app bundle, no dependencies.

**Key design choices:**

- **Standalone binary** — not a .app bundle; avoids LaunchServices overhead
- **`NSApp.setActivationPolicy(.accessory)`** — no Dock icon, terminal-only launch
- **NSTextView** — provides all standard macOS text keybindings for free (copy/paste, undo/redo, Emacs keybindings, find/replace)
- **Direct swiftc compilation** — no SPM, no Xcode project

## Build

```bash
make          # builds optimized binary
make clean    # removes binary
```

Build command: `swiftc -O -whole-module-optimization -o mu Sources/main.swift`

## Project Structure

```
Sources/main.swift   # entire application
Makefile             # build system
requirement.md       # original requirements (Japanese)
```

## Key Implementation Details

- File encoding: UTF-8 only
- Window closes = app terminates (`applicationShouldTerminateAfterLastWindowClosed`)
- Save (⌘S) writes atomically via `String.write(to:atomically:encoding:)`
- Menus are hidden (`.accessory` policy) but keyboard shortcuts still function
- Automatic quote/dash substitution is disabled (code-friendly defaults)
