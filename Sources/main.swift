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

enum LineNavigator {
    private static let lineFeed: unichar = 10
    private static let carriageReturn: unichar = 13

    static func location(ofLine requestedLine: Int, in text: String) -> Int? {
        guard requestedLine > 0 else {
            return nil
        }

        if requestedLine == 1 {
            return 0
        }

        let contents = text as NSString
        var line = 1
        var location = 0

        while location < contents.length {
            let character = contents.character(at: location)
            if isLineBreak(character) {
                if character == carriageReturn,
                   location + 1 < contents.length,
                   contents.character(at: location + 1) == lineFeed {
                    location += 1
                }

                line += 1
                if line == requestedLine {
                    return location + 1
                }
            }

            location += 1
        }

        return nil
    }

    static func lineNumber(at requestedLocation: Int, in text: String) -> Int {
        let contents = text as NSString
        let target = max(0, min(requestedLocation, contents.length))
        var line = 1
        var location = 0

        while location < target {
            let character = contents.character(at: location)
            if isLineBreak(character) {
                if character == carriageReturn,
                   location + 1 < target,
                   contents.character(at: location + 1) == lineFeed {
                    location += 1
                }

                line += 1
            }

            location += 1
        }

        return line
    }

    static func lineCount(in text: String) -> Int {
        let contents = text as NSString
        var count = 1
        var location = 0

        while location < contents.length {
            let character = contents.character(at: location)
            if isLineBreak(character) {
                if character == carriageReturn,
                   location + 1 < contents.length,
                   contents.character(at: location + 1) == lineFeed {
                    location += 1
                }

                count += 1
            }

            location += 1
        }

        return count
    }

    static func hasTrailingLineBreak(in text: String) -> Bool {
        let contents = text as NSString
        guard contents.length > 0 else {
            return false
        }

        return isLineBreak(contents.character(at: contents.length - 1))
    }

    static func isLineStart(_ location: Int, in text: String) -> Bool {
        guard location > 0 else {
            return true
        }

        let contents = text as NSString
        guard location <= contents.length else {
            return false
        }

        return isLineBreak(contents.character(at: location - 1))
    }

    private static func isLineBreak(_ character: unichar) -> Bool {
        character == lineFeed || character == carriageReturn
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

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let horizontalPadding: CGFloat = 8
    private let paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }()

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)

        clientView = textView
        updateRuleThickness()

        textView.postsFrameChangedNotifications = true
        textView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidateLineNumbers),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidateLineNumbers),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidateLineNumbers),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        updateRuleThickness()

        if textView.string.isEmpty {
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            drawLineNumber(1, at: textView.textContainerOrigin.y, lineHeight: font.ascender - font.descender + font.leading)
            return
        }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        var glyphIndex = visibleGlyphRange.location
        let maxGlyphIndex = NSMaxRange(visibleGlyphRange)

        while glyphIndex < maxGlyphIndex {
            var lineGlyphRange = NSRange(location: NSNotFound, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            guard lineGlyphRange.location != NSNotFound, lineGlyphRange.length > 0 else {
                break
            }

            let characterRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            if LineNavigator.isLineStart(characterRange.location, in: textView.string) {
                let lineNumber = LineNavigator.lineNumber(at: characterRange.location, in: textView.string)
                drawLineNumber(
                    lineNumber,
                    at: lineRect.minY + textView.textContainerOrigin.y,
                    lineHeight: lineRect.height
                )
            }

            glyphIndex = NSMaxRange(lineGlyphRange)
        }

        drawFinalEmptyLineIfNeeded(layoutManager: layoutManager, textView: textView)
    }

    @objc private func invalidateLineNumbers(_ notification: Notification) {
        updateRuleThickness()
        needsDisplay = true
    }

    private func updateRuleThickness() {
        guard let textView else {
            return
        }

        let digits = max(2, String(LineNavigator.lineCount(in: textView.string)).count)
        let sample = String(repeating: "8", count: digits)
        let width = ceil((sample as NSString).size(withAttributes: textAttributes).width + horizontalPadding * 2)
        let newThickness = max(40, width)
        if abs(ruleThickness - newThickness) > 0.5 {
            ruleThickness = newThickness
            scrollView?.tile()
        }
    }

    private func drawLineNumber(_ lineNumber: Int, at y: CGFloat, lineHeight: CGFloat) {
        guard let textView else {
            return
        }

        let pointInRuler = convert(NSPoint(x: 0, y: y), from: textView)
        let number = "\(lineNumber)" as NSString
        let drawRect = NSRect(
            x: 0,
            y: pointInRuler.y,
            width: ruleThickness - horizontalPadding,
            height: lineHeight
        )
        number.draw(in: drawRect, withAttributes: textAttributes)
    }

    private func drawFinalEmptyLineIfNeeded(layoutManager: NSLayoutManager, textView: NSTextView) {
        guard LineNavigator.hasTrailingLineBreak(in: textView.string) else {
            return
        }

        let lineRect = finalEmptyLineRect(layoutManager: layoutManager, textView: textView)
        let y = lineRect.minY + textView.textContainerOrigin.y
        let lineHeight = lineRect.height > 0 ? lineRect.height : fallbackLineHeight(for: textView)
        let lineRectInTextView = NSRect(
            x: textView.visibleRect.minX,
            y: y,
            width: textView.visibleRect.width,
            height: lineHeight
        )
        guard textView.visibleRect.intersects(lineRectInTextView) else {
            return
        }

        drawLineNumber(LineNavigator.lineCount(in: textView.string), at: y, lineHeight: lineHeight)
    }

    private func finalEmptyLineRect(layoutManager: NSLayoutManager, textView: NSTextView) -> NSRect {
        let extraLineRect = layoutManager.extraLineFragmentRect
        if !extraLineRect.isEmpty {
            return extraLineRect
        }

        guard layoutManager.numberOfGlyphs > 0 else {
            return NSRect(x: 0, y: textView.textContainerOrigin.y, width: 0, height: fallbackLineHeight(for: textView))
        }

        let previousLineRect = layoutManager.lineFragmentRect(
            forGlyphAt: layoutManager.numberOfGlyphs - 1,
            effectiveRange: nil
        )
        return NSRect(
            x: previousLineRect.minX,
            y: previousLineRect.maxY,
            width: previousLineRect.width,
            height: previousLineRect.height
        )
    }

    private func fallbackLineHeight(for textView: NSTextView) -> CGFloat {
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        return font.ascender - font.descender + font.leading
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    let window: NSWindow
    let textView: NSTextView
    let searchBar: NSView
    let searchField: SearchField
    let goToLineBar: NSView
    let lineNumberField: NSTextField
    let lineNumberMessageLabel: NSTextField
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

        goToLineBar = NSView(frame: NSRect(x: 0, y: 0, width: contentRect.width, height: 36))
        goToLineBar.wantsLayer = true
        goToLineBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        goToLineBar.isHidden = true
        goToLineBar.translatesAutoresizingMaskIntoConstraints = false
        goToLineBar.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let lineNumberLabel = NSTextField(labelWithString: "Line:")
        lineNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        goToLineBar.addSubview(lineNumberLabel)

        lineNumberField = NSTextField(frame: .zero)
        lineNumberField.placeholderString = "Line number"
        lineNumberField.font = NSFont.systemFont(ofSize: 13)
        lineNumberField.translatesAutoresizingMaskIntoConstraints = false
        goToLineBar.addSubview(lineNumberField)

        lineNumberMessageLabel = NSTextField(labelWithString: "")
        lineNumberMessageLabel.textColor = NSColor.secondaryLabelColor
        lineNumberMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        goToLineBar.addSubview(lineNumberMessageLabel)
        NSLayoutConstraint.activate([
            lineNumberLabel.leadingAnchor.constraint(equalTo: goToLineBar.leadingAnchor, constant: 8),
            lineNumberLabel.centerYAnchor.constraint(equalTo: goToLineBar.centerYAnchor),
            lineNumberField.leadingAnchor.constraint(equalTo: lineNumberLabel.trailingAnchor, constant: 8),
            lineNumberField.centerYAnchor.constraint(equalTo: goToLineBar.centerYAnchor),
            lineNumberField.widthAnchor.constraint(equalToConstant: 96),
            lineNumberMessageLabel.leadingAnchor.constraint(equalTo: lineNumberField.trailingAnchor, constant: 8),
            lineNumberMessageLabel.trailingAnchor.constraint(lessThanOrEqualTo: goToLineBar.trailingAnchor, constant: -8),
            lineNumberMessageLabel.centerYAnchor.constraint(equalTo: goToLineBar.centerYAnchor)
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
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = LineNumberRulerView(textView: textView)
        scrollView.rulersVisible = true
        containerView.addArrangedSubview(searchBar)
        containerView.addArrangedSubview(goToLineBar)
        containerView.addArrangedSubview(scrollView)
        window.contentView = containerView

        super.init()

        searchField.delegate = self
        lineNumberField.delegate = self
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
        guard let field = obj.object as? NSTextField, field === searchField else {
            return
        }

        let location = textView.selectedRange().location
        selectMatch(.forward, from: NSRange(location: location, length: 0), beepOnMiss: false)
    }

    func control(_ control: NSControl, textView fieldEditor: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control === searchField {
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

        if control === lineNumberField {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)),
                 #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                 #selector(NSResponder.insertLineBreak(_:)):
                confirmGoToLine(nil)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                hideGoToLine(nil)
                return true
            default:
                return false
            }
        }

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
        goToLineBar.isHidden = true
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

    // MARK: - Go to Line

    @objc func goToLine(_ sender: Any?) {
        let lineCount = LineNavigator.lineCount(in: textView.string)
        searchBar.isHidden = true
        goToLineBar.isHidden = false
        lineNumberField.stringValue = "\(LineNavigator.lineNumber(at: textView.selectedRange().location, in: textView.string))"
        lineNumberMessageLabel.stringValue = "1–\(lineCount), Return to jump, Esc to cancel"
        window.makeFirstResponder(lineNumberField)
        lineNumberField.selectText(nil)
    }

    private func confirmGoToLine(_ sender: Any?) {
        let lineCount = LineNavigator.lineCount(in: textView.string)
        let requestedLine = lineNumberField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lineNumber = Int(requestedLine),
              lineNumber >= 1,
              lineNumber <= lineCount,
              let location = LineNavigator.location(ofLine: lineNumber, in: textView.string) else {
            NSSound.beep()
            lineNumberMessageLabel.stringValue = "Enter a line number from 1 to \(lineCount)."
            lineNumberField.selectText(nil)
            return
        }

        let range = NSRange(location: location, length: 0)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        hideGoToLine(nil)
    }

    private func hideGoToLine(_ sender: Any?) {
        goToLineBar.isHidden = true
        window.makeFirstResponder(textView)
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
    findMenu.addItem(NSMenuItem.separator())
    findMenu.addItem(withTitle: "Go to Line…", action: #selector(AppDelegate.goToLine(_:)), keyEquivalent: "l")
    findMenuItem.submenu = findMenu

    NSApp.mainMenu = mainMenu
}

// MARK: - Run

let delegate = AppDelegate(filePath: fileURL, clearContents: clearContents)
app.delegate = delegate
buildMenu()
app.run()
