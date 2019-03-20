//
//  PreferencesEditorViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesEditorViewController: NSViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 474, height: 394)
    }

    @IBOutlet weak var codeBlockHighlight: NSButton!
    @IBOutlet weak var markdownCodeTheme: NSPopUpButton!
    @IBOutlet weak var liveImagesPreview: NSButton!
    @IBOutlet weak var inEditorFocus: NSButton!
    @IBOutlet weak var restoreCursorButton: NSButton!
    @IBOutlet weak var autocloseBrackets: NSButton!
    @IBOutlet weak var lineSpacing: NSSlider!
    @IBOutlet weak var imagesWidth: NSSlider!
    @IBOutlet weak var lineWidth: NSSlider!

    //MARK: global variables

    let storage = Storage.sharedInstance()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear() {
        self.view.window!.title = NSLocalizedString("Preferences", comment: "")

        codeBlockHighlight.state = UserDefaultsManagement.codeBlockHighlight ? NSControl.StateValue.on : NSControl.StateValue.off

        liveImagesPreview.state = UserDefaultsManagement.liveImagesPreview ? NSControl.StateValue.on : NSControl.StateValue.off

        inEditorFocus.state = UserDefaultsManagement.focusInEditorOnNoteSelect ? NSControl.StateValue.on : NSControl.StateValue.off

        restoreCursorButton.state = UserDefaultsManagement.restoreCursorPosition ? .on : .off

        autocloseBrackets.state = UserDefaultsManagement.autocloseBrackets ? .on : .off

        markdownCodeTheme.selectItem(withTitle: UserDefaultsManagement.codeTheme)

        lineSpacing.floatValue = UserDefaultsManagement.editorLineSpacing
        imagesWidth.floatValue = UserDefaultsManagement.imagesWidth
        lineWidth.floatValue = UserDefaultsManagement.lineWidth
    }

    @IBAction func liveImagesPreview(_ sender: NSButton) {
        guard let vc = ViewController.shared() else { return }

        if UserDefaultsManagement.liveImagesPreview {
            if let note = EditTextView.note, let storage = vc.editArea.textStorage, storage.length > 0 {
                let processor = ImagesProcessor(styleApplier: storage, note: note)
                processor.unLoad()
                storage.setAttributedString(note.content)
            }
        }

        UserDefaultsManagement.liveImagesPreview = (sender.state == NSControl.StateValue.on)

        if let note = EditTextView.note, !UserDefaultsManagement.preview {
            NotesTextProcessor.fullScan(note: note)
            vc.refillEditArea()
        }
    }

    @IBAction func codeBlockHighlight(_ sender: NSButton) {
        UserDefaultsManagement.codeBlockHighlight = (sender.state == NSControl.StateValue.on)

        restart()
    }

    @IBAction func markdownCodeThemeAction(_ sender: NSPopUpButton) {
        guard let vc = ViewController.shared() else { return }
        guard let item = sender.selectedItem else {
            return
        }

        UserDefaultsManagement.codeTheme = item.title

        NotesTextProcessor.hl = nil
        self.storage.fullCacheReset()
        vc.refillEditArea()
    }

    @IBAction func inEditorFocus(_ sender: NSButton) {
        UserDefaultsManagement.focusInEditorOnNoteSelect = (sender.state == .on)
    }

    @IBAction func restoreCursor(_ sender: NSButton) {
        UserDefaultsManagement.restoreCursorPosition = (sender.state == .on)
    }

    @IBAction func autocloseBrackets(_ sender: NSButton) {
        UserDefaultsManagement.autocloseBrackets = (sender.state == .on)
    }

    @IBAction func lineSpacing(_ sender: NSSlider) {
        guard let vc = ViewController.shared() else { return }
        UserDefaultsManagement.editorLineSpacing = sender.floatValue

        vc.editArea.applyLeftParagraphStyle()
    }

    @IBAction func imagesWidth(_ sender: NSSlider) {
        guard let vc = ViewController.shared() else { return }

        UserDefaultsManagement.imagesWidth = sender.floatValue

        if let note = EditTextView.note, !UserDefaultsManagement.preview {
            NotesTextProcessor.fullScan(note: note)
            vc.refillEditArea()
        }
    }

    @IBAction func lineWidth(_ sender: NSSlider) {
        guard let vc = ViewController.shared() else { return }

        UserDefaultsManagement.lineWidth = sender.floatValue

        if let _ = EditTextView.note, !UserDefaultsManagement.preview {
            vc.editArea.updateTextContainerInset()
        }
    }

    private func restart() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        exit(0)
    }
}
