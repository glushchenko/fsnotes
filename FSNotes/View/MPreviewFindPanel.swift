//
//  MPreviewFindPanel.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 21.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa
import WebKit

final class MPreviewFindPanel: NSVisualEffectView, NSSearchFieldDelegate {

    // MARK: UI

    public let searchField = NSSearchField()
    
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let doneButton = NSButton()
    private let statusLabel = NSTextField()
    private let containerView = NSView()

    public var panelHeightConstraint: NSLayoutConstraint!
    private var containerHeightConstraint: NSLayoutConstraint!

    // MARK: Callbacks

    var onSearch: ((String) -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onDone: (() -> Void)?

    // MARK: Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: Setup

    private func setupUI() {
        material = .windowBackground
        blendingMode = .behindWindow
        state = .active
        
        translatesAutoresizingMaskIntoConstraints = false
        panelHeightConstraint = heightAnchor.constraint(equalToConstant: 36)
        panelHeightConstraint.isActive = true

        setupContainer()
        setupControls()
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: 28)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerHeightConstraint
        ])
    }

    private func setupControls() {
        // Search field
        searchField.placeholderString = NSLocalizedString("Search", comment: "")
        searchField.delegate = self
        prepare(searchField)

        // Buttons
        configureButton(previousButton, systemImage: "chevron.up", action: #selector(previousClicked))
        configureButton(nextButton, systemImage: "chevron.down", action: #selector(nextClicked))

        // Status
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        prepare(statusLabel)

        // Done
        doneButton.title = NSLocalizedString("Done", comment: "")
        doneButton.bezelStyle = .texturedRounded
        doneButton.target = self
        doneButton.action = #selector(doneClicked)
        prepare(doneButton)

        layoutControls()
    }

    private func prepare(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(view)
    }

    private func configureButton(_ button: NSButton, systemImage: String, action: Selector) {
        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = action
        prepare(button)
    }

    private func layoutControls() {
        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            searchField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 200),

            previousButton.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            previousButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 32),

            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 4),
            nextButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 32),

            statusLabel.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            doneButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
            doneButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            doneButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }

    // MARK: Public API

    func show() {
        isHidden = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panelHeightConstraint.animator().constant = 36
            alphaValue = 1
        } completionHandler: {
            self.window?.makeFirstResponder(self.searchField)
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panelHeightConstraint.animator().constant = 0
            alphaValue = 0
        } completionHandler: {
            self.isHidden = true
        }
    }

    func updateStatus(current: Int, total: Int) {
        statusLabel.stringValue = total > 0 ? "\(current) from \(total)" : "Not found"
    }

    func clear() {
        searchField.stringValue = ""
        statusLabel.stringValue = ""
    }

    // MARK: Actions

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        onSearch?(sender.stringValue)
    }

    @objc private func previousClicked() {
        onPrevious?()
    }

    @objc private func nextClicked() {
        onNext?()
    }

    @objc private func doneClicked() {
        onDone?()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSSearchField {
            onSearch?(textField.stringValue)
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        let movement = obj.userInfo?["NSTextMovement"] as? Int ?? 0
        if movement == NSTextMovement.return.rawValue {
            onNext?()
        }
    }
}
