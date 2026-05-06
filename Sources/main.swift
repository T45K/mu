import AppKit

enum SearchDirection {
    case forward
    case backward
}

enum TextSearch {
    static func match(in text: String, query: String, from selectedRange: NSRange, direction: SearchDirection) -> NSRange? {
        let contents = text as NSString
        let textLength = contents.length
        let queryLength = (query as NSString).length

        guard textLength > 0, queryLength > 0 else {
            return nil
        }

        let selectionStart = max(0, min(selectedRange.location, textLength))
        let selectionEnd = max(0, min(selectedRange.location + selectedRange.length, textLength))
        let options: NSString.CompareOptions = [.caseInsensitive]

        switch direction {
        case .forward:
            let start = selectedRange.length > 0 ? selectionEnd : selectionStart
            if let range = find(in: contents, query: query, options: options, location: start, length: textLength - start) {
                return range
            }

            return find(in: contents, query: query, options: options, location: 0, length: start)
        case .backward:
            if let range = find(in: contents, query: query, options: options.union(.backwards), location: 0, length: selectionStart) {
                return range
            }

            return find(in: contents, query: query, options: options.union(.backwards), location: selectionStart, length: textLength - selectionStart)
        }
    }

    private static func find(
        in contents: NSString,
        query: String,
        options: NSString.CompareOptions,
        location: Int,
        length: Int
    ) -> NSRange? {
        guard length > 0 else {
            return nil
        }

        let range = contents.range(of: query, options: options, range: NSRange(location: location, length: length))
        return range.location == NSNotFound ? nil : range
    }
}

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

final class SearchField: NSTextField {
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            if event.modifierFlags.contains(.shift) {
                onPrevious?()
            } else {
                onNext?()
            }
        case 53:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    let window: NSWindow
    let textView: NSTextView
    let searchBar: NSView
    let searchField: SearchField
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

        // SearchBar + ScrollView + TextView
        let containerView = NSStackView(frame: contentRect)
        containerView.orientation = .vertical
        containerView.alignment = .width
        containerView.distribution = .fill
        containerView.spacing = 0
        containerView.autoresizingMask = [.width, .height]

        searchBar = NSView(frame: NSRect(x: 0, y: 0, width: contentRect.width, height: 36))
        searchBar.wantsLayer = true
        searchBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        searchBar.isHidden = true
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.heightAnchor.constraint(equalToConstant: 36).isActive = true

        searchField = SearchField(frame: .zero)
        searchField.placeholderString = "Find"
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchBar.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor)
        ])

        let scrollView = NSScrollView(frame: contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

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
        containerView.addArrangedSubview(searchBar)
        containerView.addArrangedSubview(scrollView)
        window.contentView = containerView

        super.init()

        searchField.delegate = self
        searchField.onNext = { [weak self] in
            self?.findNext(nil)
        }
        searchField.onPrevious = { [weak self] in
            self?.findPrevious(nil)
        }
        searchField.onCancel = { [weak self] in
            self?.hideFind(nil)
        }
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

    func controlTextDidChange(_ obj: Notification) {
        let location = textView.selectedRange().location
        selectMatch(.forward, from: NSRange(location: location, length: 0), beepOnMiss: false)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)),
             #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
             #selector(NSResponder.insertLineBreak(_:)):
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                findPrevious(nil)
            } else {
                findNext(nil)
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            hideFind(nil)
            return true
        default:
            return false
        }
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

    // MARK: - Find

    @objc func showFind(_ sender: Any?) {
        searchBar.isHidden = false
        if textView.selectedRange().length > 0 {
            searchField.stringValue = (textView.string as NSString).substring(with: textView.selectedRange())
        }

        window.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    @objc func hideFind(_ sender: Any?) {
        searchBar.isHidden = true
        window.makeFirstResponder(textView)
    }

    @objc func findNext(_ sender: Any?) {
        if searchBar.isHidden {
            showFind(sender)
        }

        selectMatch(.forward, from: textView.selectedRange(), beepOnMiss: true)
    }

    @objc func findPrevious(_ sender: Any?) {
        if searchBar.isHidden {
            showFind(sender)
        }

        selectMatch(.backward, from: textView.selectedRange(), beepOnMiss: true)
    }

    private func selectMatch(_ direction: SearchDirection, from selectedRange: NSRange, beepOnMiss: Bool) {
        guard let match = TextSearch.match(in: textView.string, query: searchField.stringValue, from: selectedRange, direction: direction) else {
            if beepOnMiss && !searchField.stringValue.isEmpty {
                NSSound.beep()
            }
            return
        }

        textView.setSelectedRange(match)
        textView.scrollRangeToVisible(match)
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

    // Find menu
    let findMenuItem = NSMenuItem()
    mainMenu.addItem(findMenuItem)
    let findMenu = NSMenu(title: "Find")
    findMenu.addItem(withTitle: "Find…", action: #selector(AppDelegate.showFind(_:)), keyEquivalent: "f")
    let findNextItem = NSMenuItem(title: "Find Next", action: #selector(AppDelegate.findNext(_:)), keyEquivalent: "g")
    findMenu.addItem(findNextItem)
    let findPrevItem = NSMenuItem(title: "Find Previous", action: #selector(AppDelegate.findPrevious(_:)), keyEquivalent: "G")
    findMenu.addItem(findPrevItem)
    findMenuItem.submenu = findMenu

    NSApp.mainMenu = mainMenu
}

// MARK: - Run

let delegate = AppDelegate(filePath: fileURL, clearContents: clearContents)
app.delegate = delegate
buildMenu()
app.run()
