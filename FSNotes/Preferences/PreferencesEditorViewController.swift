//
//  PreferencesEditorViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesEditorViewController: NSViewController {

    @IBOutlet weak var codeFont: NSTextField!
    @IBOutlet weak var codeBlockHighlight: NSButton!
    @IBOutlet weak var highlightIndentedCodeBlocks: NSButton!
    @IBOutlet weak var markdownCodeTheme: NSPopUpButton!
    @IBOutlet weak var liveImagesPreview: NSButton!
    @IBOutlet weak var inEditorFocus: NSButton!
    @IBOutlet weak var restoreCursorButton: NSButton!
    @IBOutlet weak var autocloseBrackets: NSButton!
    @IBOutlet weak var lineSpacing: NSSlider!
    @IBOutlet weak var imagesWidth: NSSlider!
    @IBOutlet weak var lineWidth: NSSlider!
    @IBOutlet weak var spacesInsteadTab: NSButton!
    @IBOutlet weak var marginSize: NSSlider!
    @IBOutlet weak var inlineTags: NSButton!

    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 476, height: 480)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setCodeFont()
    }

    override func viewDidAppear() {
        self.view.window!.title = NSLocalizedString("Preferences", comment: "")

        codeBlockHighlight.state = UserDefaultsManagement.codeBlockHighlight ? NSControl.StateValue.on : NSControl.StateValue.off

        highlightIndentedCodeBlocks.state = UserDefaultsManagement.indentedCodeBlockHighlighting ? NSControl.StateValue.on : NSControl.StateValue.off

        liveImagesPreview.state = UserDefaultsManagement.liveImagesPreview ? NSControl.StateValue.on : NSControl.StateValue.off

        inEditorFocus.state = UserDefaultsManagement.focusInEditorOnNoteSelect ? NSControl.StateValue.on : NSControl.StateValue.off

        restoreCursorButton.state = UserDefaultsManagement.restoreCursorPosition ? .on : .off

        autocloseBrackets.state = UserDefaultsManagement.autocloseBrackets ? .on : .off

        markdownCodeTheme.selectItem(withTitle: UserDefaultsManagement.codeTheme)

        lineSpacing.floatValue = UserDefaultsManagement.editorLineSpacing
        imagesWidth.floatValue = UserDefaultsManagement.imagesWidth
        lineWidth.floatValue = UserDefaultsManagement.lineWidth

        spacesInsteadTab.state = UserDefaultsManagement.spacesInsteadTabs ? .on : .off

        marginSize.floatValue = UserDefaultsManagement.marginSize

        inlineTags.state = UserDefaultsManagement.inlineTags ? .on : .off
    }

    //MARK: global variables

    let storage = Storage.sharedInstance()

    @IBAction func liveImagesPreview(_ sender: NSButton) {
        guard let vc = ViewController.shared() else { return }

        if UserDefaultsManagement.liveImagesPreview {
            if let note = EditTextView.note, let storage = vc.editArea.textStorage, storage.length > 0 {
                storage.setAttributedString(note.content)
            }
        }

        UserDefaultsManagement.liveImagesPreview = (sender.state == NSControl.StateValue.on)

        if let note = EditTextView.note, vc.currentPreviewState == .off {
            NotesTextProcessor.highlight(note: note)
            vc.refillEditArea()
        }
    }

    @IBAction func codeBlockHighlight(_ sender: NSButton) {
        UserDefaultsManagement.codeBlockHighlight = (sender.state == NSControl.StateValue.on)

        guard let vc = ViewController.shared() else { return }
        vc.refillEditArea()
    }

    @IBAction func markdownCodeThemeAction(_ sender: NSPopUpButton) {
        guard let vc = ViewController.shared() else { return }
        guard let item = sender.selectedItem else {
            return
        }

        UserDefaultsManagement.codeTheme = item.title

        MPreviewView.template = nil
        NotesTextProcessor.hl = nil
        vc.refillEditArea(force: true)
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

        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent("ThumbnailsBig")
        try? FileManager.default.removeItem(at: temporary)

        if let note = EditTextView.note, vc.currentPreviewState == .off {
            NotesTextProcessor.highlight(note: note)
            vc.refillEditArea()
        }
    }

    @IBAction func lineWidth(_ sender: NSSlider) {
        guard let vc = ViewController.shared() else { return }

        UserDefaultsManagement.lineWidth = sender.floatValue

        if let _ = EditTextView.note {
            vc.editArea.updateTextContainerInset()

            MPreviewView.template = nil
            NotesTextProcessor.hl = nil

            vc.editArea.clear()
            vc.refillEditArea(force: true)
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

    @IBAction func setFont(_ sender: NSButton) {
        let fontManager = NSFontManager.shared
        if UserDefaultsManagement.codeFont != nil {
            fontManager.setSelectedFont(UserDefaultsManagement.codeFont!, isMultiple: false)
        }

        fontManager.orderFrontFontPanel(self)
        fontManager.target = self
    }

    @IBAction func spacesInsteadTab(_ sender: NSButton) {
        UserDefaultsManagement.spacesInsteadTabs = (sender.state == .on)
    }

    @IBAction func marginSize(_ sender: NSSlider) {
        guard let vc = ViewController.shared() else { return }

        UserDefaultsManagement.marginSize = sender.floatValue

        if let _ = EditTextView.note {
            vc.editArea.updateTextContainerInset()

            MPreviewView.template = nil
            NotesTextProcessor.hl = nil

            vc.editArea.clear()
            vc.refillEditArea(force: true)
        }
    }

    @IBAction func changeFont(_ sender: Any?) {
        guard let vc = ViewController.shared() else { return }

        let fontManager = NSFontManager.shared
        let newFont = fontManager.convert(UserDefaultsManagement.codeFont!)
        UserDefaultsManagement.codeFont = newFont
        NotesTextProcessor.codeFont = newFont

        MPreviewView.template = nil
        NotesTextProcessor.hl = nil

        vc.editArea.clear()
        vc.refillEditArea(force: true)

        setCodeFont()
    }

    private func setCodeFont() {
        codeFont.font = NSFont(name: UserDefaultsManagement.codeFont.fontName, size: 13)
        codeFont.stringValue = "\(UserDefaultsManagement.codeFont.fontName) \(UserDefaultsManagement.codeFont.pointSize)pt"
    }

    @IBAction func inlineTags(_ sender: NSButton) {
        UserDefaultsManagement.inlineTags = (sender.state == .on)

        guard let vc = ViewController.shared() else { return }

        Storage.sharedInstance().tags = []

        for note in Storage.sharedInstance().noteList {
            note.tags = []

            if UserDefaultsManagement.inlineTags {
                _ = note.scanContentTags()
            }
        }

        vc.sidebarOutlineView.reloadSidebar()
    }

    @IBAction func highlightIndentedCodeBlocks(_ sender: NSButton) {
        UserDefaultsManagement.indentedCodeBlockHighlighting = (sender.state == NSControl.StateValue.on)

        guard let vc = ViewController.shared() else { return }
        vc.refillEditArea()
    }

}
