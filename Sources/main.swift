import AppKit

// MARK: - Parse command line arguments

let fileURL: URL
let clearContents: Bool

if CommandLine.arguments.count >= 2 {
    let filename = CommandLine.arguments[1]
    if filename.hasPrefix("/") {
        fileURL = URL(fileURLWithPath: filename)
    } else {
        let cwd = FileManager.default.currentDirectoryPath
        fileURL = URL(fileURLWithPath: cwd).appendingPathComponent(filename)
    }
    clearContents = false
} else {
    fileURL = URL(fileURLWithPath: "/tmp/mu.txt")
    clearContents = true
}

// MARK: - Application setup

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class PlainTextTextView: NSTextView {
    override func paste(_ sender: Any?) {
        guard let plainText = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }

        insertText(plainText, replacementRange: selectedRange())
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let window: NSWindow
    let textView: NSTextView
    let filePath: URL
    let clearContents: Bool

    init(filePath: URL, clearContents: Bool) {
        self.filePath = filePath
        self.clearContents = clearContents

        // Window
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = filePath.lastPathComponent
        window.center()

        // ScrollView + TextView
        let scrollView = NSScrollView(frame: contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]

        textView = PlainTextTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Horizontal scroll setup for long lines
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        window.contentView = scrollView

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if clearContents {
            // Create or truncate the file
            FileManager.default.createFile(atPath: filePath.path, contents: nil)
            textView.string = ""
        } else if FileManager.default.fileExists(atPath: filePath.path) {
            do {
                let content = try String(contentsOf: filePath, encoding: .utf8)
                textView.string = content
            } catch {
                fputs("Warning: Could not read file: \(error.localizedDescription)\n", stderr)
            }
        }

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Save

    @objc func saveDocument(_ sender: Any?) {
        do {
            try textView.string.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Save Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

// MARK: - Menu setup

func buildMenu() {
    let mainMenu = NSMenu()

    // App menu (hidden in .accessory mode, but shortcuts still work)
    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit mu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appMenuItem.submenu = appMenu

    // File menu
    let fileMenuItem = NSMenuItem()
    mainMenu.addItem(fileMenuItem)
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "Save", action: #selector(AppDelegate.saveDocument(_:)), keyEquivalent: "s")
    fileMenuItem.submenu = fileMenu

    // Edit menu (enables standard edit shortcuts)
    let editMenuItem = NSMenuItem()
    mainMenu.addItem(editMenuItem)
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editMenuItem.submenu = editMenu

    // Find menu (enables ⌘F)
    let findMenuItem = NSMenuItem()
    mainMenu.addItem(findMenuItem)
    let findMenu = NSMenu(title: "Find")
    findMenu.addItem(withTitle: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
    let findNextItem = NSMenuItem(title: "Find Next", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
    findNextItem.tag = Int(NSFindPanelAction.next.rawValue)
    findMenu.addItem(findNextItem)
    let findPrevItem = NSMenuItem(title: "Find Previous", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "G")
    findPrevItem.tag = Int(NSFindPanelAction.previous.rawValue)
    findMenu.addItem(findPrevItem)
    findMenu.addItem(withTitle: "Use Selection for Find", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "e")
    findMenuItem.submenu = findMenu

    NSApp.mainMenu = mainMenu
}

// MARK: - Run

let delegate = AppDelegate(filePath: fileURL, clearContents: clearContents)
app.delegate = delegate
buildMenu()
app.run()
