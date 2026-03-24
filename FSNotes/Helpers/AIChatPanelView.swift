//
//  AIChatPanelView.swift
//  FSNotes
//
//  AI assistant chat panel for reviewing, editing, and transforming notes.
//

import Cocoa

class AIChatPanelView: NSView {

    private var messagesScrollView: NSScrollView!
    private var messagesStack: NSStackView!
    private var inputTextView: NSTextView!
    private var inputScrollView: NSScrollView!
    private var sendButton: NSButton!
    private var headerLabel: NSTextField!
    private var closeButton: NSButton!
    private var quickActionsPopup: NSPopUpButton!

    private var messages: [ChatMessage] = []
    private var isStreaming = false
    private var currentStreamingLabel: NSTextField?

    weak var editorViewController: EditorViewController?

    static let panelWidth: CGFloat = 320

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Left border
        let border = NSBox()
        border.boxType = .separator
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)

        // Header
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerStack)

        headerLabel = NSTextField(labelWithString: "AI Assistant")
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        closeButton = NSButton()
        closeButton.bezelStyle = .accessoryBarAction
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        headerStack.addArrangedSubview(headerLabel)
        headerStack.addArrangedSubview(closeButton)

        // Quick actions
        quickActionsPopup = NSPopUpButton()
        quickActionsPopup.pullsDown = true
        quickActionsPopup.translatesAutoresizingMaskIntoConstraints = false
        (quickActionsPopup.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom

        quickActionsPopup.addItem(withTitle: "Quick Actions...")
        quickActionsPopup.addItem(withTitle: "Summarize this note")
        quickActionsPopup.addItem(withTitle: "Fix grammar and spelling")
        quickActionsPopup.addItem(withTitle: "Make more concise")
        quickActionsPopup.addItem(withTitle: "Expand on this")
        quickActionsPopup.addItem(withTitle: "Generate table of contents")
        quickActionsPopup.addItem(withTitle: "Translate to English")
        quickActionsPopup.addItem(withTitle: "Translate to Spanish")
        quickActionsPopup.addItem(withTitle: "Translate to French")
        quickActionsPopup.target = self
        quickActionsPopup.action = #selector(quickActionSelected)
        addSubview(quickActionsPopup)

        // Messages area
        messagesScrollView = NSScrollView()
        messagesScrollView.hasVerticalScroller = true
        messagesScrollView.hasHorizontalScroller = false
        messagesScrollView.borderType = .noBorder
        messagesScrollView.drawsBackground = false
        messagesScrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messagesScrollView)

        messagesStack = NSStackView()
        messagesStack.orientation = .vertical
        messagesStack.spacing = 8
        messagesStack.alignment = .leading
        messagesStack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.documentView = messagesStack
        clipView.drawsBackground = false
        messagesScrollView.contentView = clipView

        // Input area
        inputScrollView = NSScrollView()
        inputScrollView.hasVerticalScroller = true
        inputScrollView.borderType = .bezelBorder
        inputScrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inputScrollView)

        inputTextView = NSTextView()
        inputTextView.isEditable = true
        inputTextView.isRichText = false
        inputTextView.font = NSFont.systemFont(ofSize: 13)
        inputTextView.isVerticallyResizable = true
        inputTextView.isHorizontallyResizable = false
        inputTextView.textContainer?.widthTracksTextView = true
        inputTextView.delegate = self
        inputScrollView.documentView = inputTextView

        sendButton = NSButton()
        sendButton.bezelStyle = .accessoryBarAction
        sendButton.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Send")
        sendButton.imagePosition = .imageOnly
        sendButton.target = self
        sendButton.action = #selector(sendMessage)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sendButton)

        // Layout
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.widthAnchor.constraint(equalToConstant: 1),

            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            quickActionsPopup.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 4),
            quickActionsPopup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            quickActionsPopup.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            messagesScrollView.topAnchor.constraint(equalTo: quickActionsPopup.bottomAnchor, constant: 8),
            messagesScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            messagesScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            messagesScrollView.bottomAnchor.constraint(equalTo: inputScrollView.topAnchor, constant: -8),

            messagesStack.widthAnchor.constraint(equalTo: messagesScrollView.widthAnchor, constant: -16),

            inputScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            inputScrollView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -4),
            inputScrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            inputScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            inputScrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 100),

            sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            sendButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            sendButton.widthAnchor.constraint(equalToConstant: 30),
            sendButton.heightAnchor.constraint(equalToConstant: 30),
        ])

        addEmptyStateLabel()
    }

    private func addEmptyStateLabel() {
        let label = NSTextField(wrappingLabelWithString: "Ask the AI to review, edit, summarize, or transform the current note.")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.tag = 999 // marker for removal
        messagesStack.addArrangedSubview(label)
    }

    // MARK: - Actions

    @objc private func closePanel() {
        if let vc = ViewController.shared() {
            vc.toggleAIChat(self)
        }
    }

    @objc private func quickActionSelected() {
        let index = quickActionsPopup.indexOfSelectedItem
        guard index > 0 else { return }
        let title = quickActionsPopup.titleOfSelectedItem ?? ""
        quickActionsPopup.selectItem(at: 0)
        sendUserMessage(title)
    }

    @objc private func sendMessage() {
        let text = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputTextView.string = ""
        sendUserMessage(text)
    }

    private func sendUserMessage(_ text: String) {
        guard !isStreaming else { return }

        // Remove empty state
        messagesStack.arrangedSubviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }

        // Add user message bubble
        addMessageBubble(text: text, isUser: true)
        messages.append(ChatMessage(role: .user, content: text))

        // Get note content
        let noteContent = editorViewController?.vcEditor?.note?.content.string ?? ""

        // Get AI provider
        guard let provider = AIServiceFactory.createProvider() else {
            addMessageBubble(text: "No API key configured. Go to Preferences to set one.", isUser: false, isError: true)
            return
        }

        // Start streaming response
        isStreaming = true
        sendButton.isEnabled = false

        let streamingLabel = createStreamingBubble()
        currentStreamingLabel = streamingLabel

        provider.sendMessage(messages: messages, noteContent: noteContent, onToken: { [weak self] token in
            guard let label = self?.currentStreamingLabel else { return }
            label.stringValue += token
            self?.scrollToBottom()
        }, onComplete: { [weak self] result in
            guard let self = self else { return }
            self.isStreaming = false
            self.sendButton.isEnabled = true
            self.currentStreamingLabel = nil

            switch result {
            case .success(let fullText):
                self.messages.append(ChatMessage(role: .assistant, content: fullText))
                // Add Apply button if it looks like an edit suggestion
                if fullText.contains("```") || fullText.count > 100 {
                    self.addApplyButton(for: fullText)
                }
            case .failure(let error):
                self.addMessageBubble(text: "Error: \(error.localizedDescription)", isUser: false, isError: true)
            }
        })
    }

    // MARK: - Message Bubbles

    private func addMessageBubble(text: String, isUser: Bool, isError: Bool = false) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.isSelectable = true
        label.translatesAutoresizingMaskIntoConstraints = false

        let bubble = NSView()
        bubble.wantsLayer = true
        bubble.translatesAutoresizingMaskIntoConstraints = false

        if isError {
            bubble.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
            label.textColor = .systemRed
        } else if isUser {
            bubble.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        } else {
            bubble.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.05).cgColor
        }
        bubble.layer?.cornerRadius = 8

        bubble.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -8),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: AIChatPanelView.panelWidth - 40),
        ])

        messagesStack.addArrangedSubview(bubble)

        if isUser {
            bubble.trailingAnchor.constraint(equalTo: messagesStack.trailingAnchor).isActive = true
        }

        scrollToBottom()
    }

    private func createStreamingBubble() -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = NSFont.systemFont(ofSize: 13)
        label.isSelectable = true
        label.translatesAutoresizingMaskIntoConstraints = false

        let bubble = NSView()
        bubble.wantsLayer = true
        bubble.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.05).cgColor
        bubble.layer?.cornerRadius = 8
        bubble.translatesAutoresizingMaskIntoConstraints = false

        bubble.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -8),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: AIChatPanelView.panelWidth - 40),
        ])

        messagesStack.addArrangedSubview(bubble)
        scrollToBottom()
        return label
    }

    private func addApplyButton(for text: String) {
        let button = NSButton(title: "Apply to Note", target: self, action: #selector(applyToNote(_:)))
        button.bezelStyle = .accessoryBarAction
        button.tag = messages.count - 1 // store message index
        button.translatesAutoresizingMaskIntoConstraints = false
        messagesStack.addArrangedSubview(button)
        scrollToBottom()
    }

    @objc private func applyToNote(_ sender: NSButton) {
        let msgIndex = sender.tag
        guard msgIndex >= 0, msgIndex < messages.count else { return }

        let content = messages[msgIndex].content
        guard let editor = editorViewController?.vcEditor,
              let note = editor.note else { return }

        // Extract code block content if present, otherwise use full response
        var textToInsert = content
        if let codeBlockRange = content.range(of: "```[^\n]*\n", options: .regularExpression),
           let closeRange = content.range(of: "\n```", options: [], range: codeBlockRange.upperBound..<content.endIndex) {
            textToInsert = String(content[codeBlockRange.upperBound..<closeRange.lowerBound])
        }

        // Replace note content
        let fullRange = NSRange(location: 0, length: editor.textStorage?.length ?? 0)
        editor.insertText(textToInsert, replacementRange: fullRange)

        _ = note.save(content: NSMutableAttributedString(attributedString: editor.attributedString()))
    }

    private func scrollToBottom() {
        DispatchQueue.main.async {
            if let documentView = self.messagesScrollView.documentView {
                documentView.scrollToEndOfDocument(nil)
            }
        }
    }
}

// MARK: - NSTextViewDelegate

extension AIChatPanelView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSEvent.modifierFlags.contains(.shift) {
                return false // Allow Shift+Return for newline
            }
            sendMessage()
            return true // Return sends message
        }
        return false
    }
}
