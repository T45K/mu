# mu

A text editor that launches before your finger leaves the key.

mu is a macOS-native GUI text editor built for one thing: **getting out of your way**. No project files, no plugins, no settings to tweak. Just type `mu notes.txt` and start writing.

## Why mu?

Terminal editors are fast but modal. GUI editors are friendly but slow. mu is both — a native AppKit window that pops up instantly from your terminal, with every macOS keybinding you already know.

- **Instant startup** — ~60KB native binary, no framework overhead, no Electron, no JVM
- **Zero learning curve** — if you can use TextEdit, you can use mu
- **Terminal-first** — launched from the command line, stays out of your Dock
- **One job, done well** — edit text, save with `⌘S`, done

## Install

```bash
curl -fsSL https://github.com/T45K/mu/releases/download/v0.1.2/mu -o ~/.local/bin/mu
chmod +x ~/.local/bin/mu
```

### Build from source

```bash
make
ln -sf "$(pwd)/mu" ~/.local/bin/mu    # or wherever your PATH points
```

## Usage

```bash
mu filename.txt        # open existing file or create new
mu                     # open a scratch buffer (/tmp/mu.txt, cleared on each launch)
```

That's it.

## Keybindings

mu follows standard macOS conventions. Everything works the way you expect:

| Shortcut | Action |
|----------|--------|
| `⌘S` | Save |
| `⌘Z` / `⇧⌘Z` | Undo / Redo |
| `⌘C` / `⌘V` / `⌘X` | Copy / Paste / Cut |
| `⌘A` | Select All |
| `⌘F` | Find |
| `Return` / `⇧Return` in Find | Find Next / Previous |
| `Esc` in Find | Close Find |
| `⌘G` / `⇧⌘G` | Find Next / Previous |
| `⌘Q` / `⌘W` | Quit |
| `⌃A` / `⌃E` | Beginning / End of line |
| `⌥←` / `⌥→` | Word navigation |
| ... | Every other standard macOS text keybinding |

Find is case-insensitive and wraps around when it reaches the beginning or end of the document.

## Requirements

- macOS 13+
- Swift toolchain (Xcode Command Line Tools)

## License

MIT
