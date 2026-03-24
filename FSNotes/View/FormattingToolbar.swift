//
//  FormattingToolbar.swift
//  FSNotes
//
//  Created on 2026-03-23.
//

import Cocoa

class FormattingToolbar: NSView {

    private var stackView: NSStackView!
    private var buttons: [String: NSButton] = [:]

    static let toolbarHeight: CGFloat = 32

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    private func setupToolbar() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let border = NSBox()
        border.boxType = .separator
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1)
        ])

        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 2
        stackView.alignment = .centerY
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Navigation buttons (target ViewController directly)
        addButton(id: "back", symbol: "chevron.left", tooltip: "Back", action: #selector(ViewController.navigateBack(_:)))
        addButton(id: "forward", symbol: "chevron.right", tooltip: "Forward", action: #selector(ViewController.navigateForward(_:)))
        // Start disabled
        buttons["back"]?.isEnabled = false
        buttons["forward"]?.isEnabled = false

        addSeparator()

        // All buttons use target=nil to route through the first responder chain.
        // EditTextView has @IBAction methods for each of these selectors.

        // Style group
        addButton(id: "bold", symbol: "bold", tooltip: "Bold (Cmd+B)", action: #selector(EditTextView.boldMenu(_:)))
        addButton(id: "italic", symbol: "italic", tooltip: "Italic (Cmd+I)", action: #selector(EditTextView.italicMenu(_:)))
        addButton(id: "underline", symbol: "underline", tooltip: "Underline (Cmd+U)", action: #selector(EditTextView.underlineMenu(_:)))
        addButton(id: "strikethrough", symbol: "strikethrough", tooltip: "Strikethrough", action: #selector(EditTextView.strikeMenu(_:)))

        addSeparator()

        // Heading group
        addButton(id: "h1", title: "H1", tooltip: "Heading 1", action: #selector(EditTextView.headerMenu1(_:)))
        addButton(id: "h2", title: "H2", tooltip: "Heading 2", action: #selector(EditTextView.headerMenu2(_:)))
        addButton(id: "h3", title: "H3", tooltip: "Heading 3", action: #selector(EditTextView.headerMenu3(_:)))

        addSeparator()

        // Block group
        addButton(id: "quote", symbol: "text.quote", tooltip: "Quote", action: #selector(EditTextView.quoteMenu(_:)))
        addButton(id: "bulletList", symbol: "list.bullet", tooltip: "Bullet List", action: #selector(EditTextView.bulletListMenu(_:)))
        addButton(id: "numberedList", symbol: "list.number", tooltip: "Numbered List", action: #selector(EditTextView.numberedListMenu(_:)))
        addButton(id: "checkbox", symbol: "checkmark.square", tooltip: "Checkbox", action: #selector(EditTextView.todo(_:)))

        addSeparator()

        // Insert group
        addButton(id: "link", symbol: "link", tooltip: "Insert Link (Cmd+K)", action: #selector(EditTextView.linkMenu(_:)))
        addButton(id: "wikilink", symbol: "doc.text", tooltip: "Wiki-Link to Note", action: #selector(EditTextView.wikiLinks(_:)))
        addButton(id: "image", symbol: "photo", tooltip: "Insert Image/File", action: #selector(EditTextView.insertFileOrImage(_:)))
        addButton(id: "table", symbol: "tablecells", tooltip: "Insert Table", action: #selector(EditTextView.insertTableMenu(_:)))
        addButton(id: "codeBlock", symbol: "chevron.left.forwardslash.chevron.right", tooltip: "Code Block", action: #selector(EditTextView.insertCodeBlock(_:)))
        addButton(id: "horizontalRule", symbol: "minus", tooltip: "Horizontal Rule", action: #selector(EditTextView.horizontalRuleMenu(_:)))

        addSeparator()

        // AI Chat
        addButton(id: "aiChat", symbol: "bubble.left.and.text.bubble.right", tooltip: "AI Assistant", action: #selector(ViewController.toggleAIChat(_:)))
    }

    // MARK: - Button Creation

    private func addButton(id: String, symbol: String, tooltip: String, action: Selector) {
        let button = NSButton()
        button.bezelStyle = .accessoryBarAction
        button.isBordered = true
        button.setButtonType(.momentaryPushIn)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.target = nil // routes through first responder chain
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.refusesFirstResponder = true // keep focus on EditTextView

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 24)
        ])

        stackView.addArrangedSubview(button)
        buttons[id] = button
    }

    private func addButton(id: String, title: String, tooltip: String, action: Selector) {
        let button = NSButton()
        button.bezelStyle = .accessoryBarAction
        button.isBordered = true
        button.setButtonType(.momentaryPushIn)
        button.title = title
        button.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        button.toolTip = tooltip
        button.target = nil // routes through first responder chain
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.refusesFirstResponder = true // keep focus on EditTextView

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 24)
        ])

        stackView.addArrangedSubview(button)
        buttons[id] = button
    }

    private func addSeparator() {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 18)
        ])

        stackView.addArrangedSubview(separator)
    }

    // MARK: - Button State Updates

    func updateButtonStates(for editor: EditTextView) {
        guard let storage = editor.textStorage, storage.length > 0 else {
            resetAllButtons()
            return
        }

        let range = editor.selectedRange()
        let location = min(range.location, storage.length - 1)
        guard location >= 0 else {
            resetAllButtons()
            return
        }

        if let font = storage.attribute(.font, at: location, effectiveRange: nil) as? NSFont {
            let traits = font.fontDescriptor.symbolicTraits
            setButtonState("bold", active: traits.contains(.bold))
            setButtonState("italic", active: traits.contains(.italic))

            let baseSize = UserDefaultsManagement.noteFont.pointSize
            setButtonState("h1", active: font.pointSize >= baseSize * 2)
            setButtonState("h2", active: font.pointSize >= baseSize * 1.5 && font.pointSize < baseSize * 2)
            setButtonState("h3", active: font.pointSize >= baseSize * 1.17 && font.pointSize < baseSize * 1.5)
        }

        let hasStrike = storage.attribute(.strikethroughStyle, at: location, effectiveRange: nil) != nil
        setButtonState("strikethrough", active: hasStrike)

        let hasUnderline = storage.attribute(.underlineStyle, at: location, effectiveRange: nil) != nil
        setButtonState("underline", active: hasUnderline)

        let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let paragraphText = (storage.string as NSString).substring(with: paragraphRange).trimmingCharacters(in: .whitespaces)

        setButtonState("quote", active: paragraphText.hasPrefix(">"))
        setButtonState("bulletList", active: paragraphText.hasPrefix("- ") || paragraphText.hasPrefix("* ") || paragraphText.hasPrefix("+ "))
        setButtonState("numberedList", active: paragraphText.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil)
        setButtonState("checkbox", active: paragraphText.hasPrefix("- [ ]") || paragraphText.hasPrefix("- [x]"))
    }

    private func setButtonState(_ id: String, active: Bool) {
        buttons[id]?.state = active ? .on : .off
    }

    private func resetAllButtons() {
        buttons.values.forEach { $0.state = .off }
    }

    func updateNavigationButtons(canGoBack: Bool, canGoForward: Bool) {
        buttons["back"]?.isEnabled = canGoBack
        buttons["forward"]?.isEnabled = canGoForward
    }
}
