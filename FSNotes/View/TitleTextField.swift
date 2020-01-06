//
//  TitleTextField.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 5/10/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

class TitleTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command)
            && event.keyCode == kVK_ANSI_C
            && !event.modifierFlags.contains(.shift)
            && !event.modifierFlags.contains(.control)
            && !event.modifierFlags.contains(.option) {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(self.stringValue, forType: NSPasteboard.PasteboardType.string)
        }

        return super.performKeyEquivalent(with: event)
    }

    override func textDidEndEditing(_ notification: Notification) {
        guard let vc = ViewController.shared(), let fn = EditTextView.note?.getFileName() else { return }

        vc.updateTitle(newTitle: fn)
    }
}
