//
//  EditTextView+Clicked.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 13.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation
import AppKit

extension EditTextView {
    public func handleEmailLink(_ link: Any) -> Bool {
        guard let emailString = link as? String,
              emailString.isValidEmail(),
              let mailURL = URL(string: "mailto:\(emailString)") else {
            return false
        }
        
        NSWorkspace.shared.open(mailURL)
        return true
    }

    public func handleAnchorLink(_ link: Any) -> Bool {
        guard let linkString = link as? String,
              linkString.startsWith(string: "#") else {
            return false
        }
        
        let title = String(linkString.dropFirst()).replacingOccurrences(of: "-", with: " ")
        guard let textRange = textStorage?.string.range(of: "# " + title),
              let nsRange = textStorage?.string.nsRange(from: textRange) else {
            return false
        }
        
        setSelectedRange(nsRange)
        scrollRangeToVisible(nsRange)
        return true
    }

    public func isAttachmentAtPosition(_ charIndex: Int) -> Bool {
        let range = NSRange(location: charIndex, length: 1)
        let char = attributedSubstring(forProposedRange: range, actualRange: nil)
        return char?.attribute(.attachment, at: 0, effectiveRange: nil) != nil
    }

    public func handleRegularLink(_ link: Any, at charIndex: Int) -> Bool {
        guard let url = convertToURL(link) else {
            super.clicked(onLink: link, at: charIndex)
            return true
        }
        
        // Handle file:// URLs
        if url.scheme == "file" {
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            return true
        }
        
        // Handle non-fsnotes URLs with modifiers
        if url.scheme != "fsnotes" {
            if let handled = handleURLWithModifiers(url, at: charIndex) {
                return handled
            }
        }
        
        super.clicked(onLink: link, at: charIndex)
        return true
    }

    private func convertToURL(_ link: Any) -> URL? {
        if let url = link as? URL {
            return url
        }
        
        if let linkString = link as? String {
            return linkString.createURL(for: self.note)
        }
        
        return nil
    }

    private func handleURLWithModifiers(_ url: URL, at charIndex: Int) -> Bool? {
        guard let event = NSApp.currentEvent else {
            return nil
        }
        
        // Shift: Open without activation
        if event.modifierFlags.contains(.shift) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.open(url, configuration: configuration, completionHandler: nil)
            return true
        }
        
        // Command: Open normally
        if event.modifierFlags.contains(.command) {
            NSWorkspace.shared.open(url)
            return true
        }
        
        // No modifier: Check user preferences
        if !UserDefaultsManagement.clickableLinks {
            setSelectedRange(NSRange(location: charIndex, length: 0))
            return true
        }
        
        return nil
    }
}
