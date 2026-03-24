//
//  BlockSourceEditor.swift
//  FSNotes
//
//  Click-to-edit popup for mermaid diagrams and LaTeX math blocks.
//

import Cocoa

class BlockSourceEditor {

    enum BlockType {
        case mermaid
        case math
    }

    /// Show a source editor sheet for a rendered block.
    /// - Parameters:
    ///   - source: Current source text
    ///   - type: Block type (mermaid or math)
    ///   - window: Parent window for the sheet
    ///   - completion: Called with updated source, or nil if cancelled
    static func show(source: String, type: BlockType, in window: NSWindow, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = type == .mermaid ? "Edit Mermaid Diagram" : "Edit Math Expression"
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.string = source
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        container.addSubview(scrollView)

        alert.accessoryView = container

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                completion(textView.string)
            } else {
                completion(nil)
            }
        }

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
    }
}
