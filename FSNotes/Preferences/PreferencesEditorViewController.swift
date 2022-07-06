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
    @IBOutlet weak var indentUsing: NSPopUpButton!
    @IBOutlet weak var inEditorFocus: NSButton!
    @IBOutlet weak var restoreCursorButton: NSButton!
    @IBOutlet weak var autocloseBrackets: NSButton!
    @IBOutlet weak var lineSpacing: NSSlider!
    @IBOutlet weak var imagesWidth: NSSlider!
    @IBOutlet weak var lineWidth: NSSlider!
    @IBOutlet weak var marginSize: NSSlider!
    @IBOutlet weak var inlineTags: NSButton!

    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 476, height: 495)
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
        indentUsing.selectItem(at: UserDefaultsManagement.indentUsing)
        restoreCursorButton.state = UserDefaultsManagement.restoreCursorPosition ? .on : .off

        autocloseBrackets.state = UserDefaultsManagement.autocloseBrackets ? .on : .off

        markdownCodeTheme.selectItem(withTitle: UserDefaultsManagement.codeTheme)

        lineSpacing.floatValue = UserDefaultsManagement.editorLineSpacing
        imagesWidth.floatValue = UserDefaultsManagement.imagesWidth
        lineWidth.floatValue = UserDefaultsManagement.lineWidth

        marginSize.floatValue = UserDefaultsManagement.marginSize

        inlineTags.state = UserDefaultsManagement.inlineTags ? .on : .off
    }

    //MARK: global variables

    let storage = Storage.sharedInstance()

    @IBAction func liveImagesPreview(_ sender: NSButton) {
        let editors = AppDelegate.getEditTextViews()
        
        for editor in editors {
            if UserDefaultsManagement.liveImagesPreview {
                if let note = editor.note, let storage = editor.textStorage, storage.length > 0 {
                    storage.setAttributedString(note.content)
                }
            }

            UserDefaultsManagement.liveImagesPreview = (sender.state == NSControl.StateValue.on)

            if let note = editor.note, let evc = editor.editorViewController, evc.currentPreviewState == .off {
                NotesTextProcessor.highlight(note: note)
                evc.refillEditArea()
            }
        }
    }

    @IBAction func codeBlockHighlight(_ sender: NSButton) {
        UserDefaultsManagement.codeBlockHighlight = (sender.state == NSControl.StateValue.on)
        Storage.sharedInstance().resetCacheAttributes()

        let editors = AppDelegate.getEditTextViews()
        
        for editor in editors {
            if let evc = editor.editorViewController {
                evc.refillEditArea(force: true)
            }
        }
    }

    @IBAction func markdownCodeThemeAction(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else {
            return
        }

        Storage.sharedInstance().resetCacheAttributes()
        UserDefaultsManagement.codeTheme = item.title

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                editor.textStorage?.updateParagraphStyle()

                MPreviewView.template = nil
                NotesTextProcessor.hl = nil

                evc.refillEditArea(force: true)
            }
        }
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
        UserDefaultsManagement.editorLineSpacing = sender.floatValue

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                editor.textStorage?.updateParagraphStyle()

                MPreviewView.template = nil
                NotesTextProcessor.hl = nil

                evc.refillEditArea(force: true)
            }
        }
    }

    @IBAction func imagesWidth(_ sender: NSSlider) {
        UserDefaultsManagement.imagesWidth = sender.floatValue

        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent("ThumbnailsBig")
        try? FileManager.default.removeItem(at: temporary)

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let note = editor.note, let evc = editor.editorViewController, evc.currentPreviewState == .off {
                NotesTextProcessor.highlight(note: note)
                
                evc.refillEditArea()
            }
        }
    }

    @IBAction func lineWidth(_ sender: NSSlider) {
        UserDefaultsManagement.lineWidth = sender.floatValue

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                editor.updateTextContainerInset()

                MPreviewView.template = nil
                NotesTextProcessor.hl = nil

                evc.refillEditArea(force: true)
            }
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
        fontManager.setSelectedFont(UserDefaultsManagement.codeFont, isMultiple: false)

        fontManager.orderFrontFontPanel(self)
        fontManager.target = self
    }

    @IBAction func indentUsing(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else {
            return
        }
        
        UserDefaultsManagement.indentUsing = item.tag
    }

    @IBAction func marginSize(_ sender: NSSlider) {
        UserDefaultsManagement.marginSize = sender.floatValue

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                editor.updateTextContainerInset()
    
                MPreviewView.template = nil
                NotesTextProcessor.hl = nil
    
                evc.refillEditArea(force: true)
            }
        }
    }

    @IBAction func changeFont(_ sender: Any?) {
        let fontManager = NSFontManager.shared
        let newFont = fontManager.convert(UserDefaultsManagement.codeFont)
        UserDefaultsManagement.codeFont = newFont
        NotesTextProcessor.codeFont = newFont

        Storage.sharedInstance().resetCacheAttributes()

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                MPreviewView.template = nil
                NotesTextProcessor.hl = nil
                evc.refillEditArea(force: true)
            }
        }
        
        setCodeFont()
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

        Storage.sharedInstance().resetCacheAttributes()
        
        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                evc.refillEditArea()
            }
        }
    }
    
    private func setCodeFont() {
        let familyName = UserDefaultsManagement.codeFont.familyName ?? "Source Code Pro"

        codeFont.font = NSFont(name: familyName, size: 13)
        codeFont.stringValue = "\(familyName) \(UserDefaultsManagement.codeFont.pointSize)pt"
    }
}
