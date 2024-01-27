//
//  PreferencesEditorViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesEditorViewController: NSViewController {

    @IBOutlet weak var codeFontPreview: NSTextField!
    @IBOutlet weak var noteFontPreview: NSTextField!
    @IBOutlet weak var codeBlockHighlight: NSButton!
    @IBOutlet weak var highlightIndentedCodeBlocks: NSButton!
    @IBOutlet weak var markdownCodeTheme: NSPopUpButton!
    @IBOutlet weak var liveImagesPreview: NSButton!
    @IBOutlet weak var indentUsing: NSPopUpButton!
    @IBOutlet weak var inEditorFocus: NSButton!
    @IBOutlet weak var autocloseBrackets: NSButton!
    @IBOutlet weak var lineSpacing: NSSlider!
    @IBOutlet weak var imagesWidth: NSSlider!
    @IBOutlet weak var lineWidth: NSSlider!
    @IBOutlet weak var marginSize: NSSlider!
    @IBOutlet weak var inlineTags: NSButton!
    @IBOutlet weak var clickableLinks: NSButton!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 550, height: 495)
    }

    override func viewDidAppear() {
        self.view.window!.title = NSLocalizedString("Settings", comment: "")

        codeBlockHighlight.state = UserDefaultsManagement.codeBlockHighlight ? NSControl.StateValue.on : NSControl.StateValue.off

        highlightIndentedCodeBlocks.state = UserDefaultsManagement.indentedCodeBlockHighlighting ? NSControl.StateValue.on : NSControl.StateValue.off

        liveImagesPreview.state = UserDefaultsManagement.liveImagesPreview ? NSControl.StateValue.on : NSControl.StateValue.off

        inEditorFocus.state = UserDefaultsManagement.focusInEditorOnNoteSelect ? NSControl.StateValue.on : NSControl.StateValue.off
        indentUsing.selectItem(at: UserDefaultsManagement.indentUsing)
        autocloseBrackets.state = UserDefaultsManagement.autocloseBrackets ? .on : .off

        markdownCodeTheme.selectItem(withTitle: UserDefaultsManagement.codeTheme)

        lineSpacing.floatValue = UserDefaultsManagement.editorLineSpacing
        imagesWidth.floatValue = UserDefaultsManagement.imagesWidth
        lineWidth.floatValue = UserDefaultsManagement.lineWidth

        marginSize.floatValue = UserDefaultsManagement.marginSize

        inlineTags.state = UserDefaultsManagement.inlineTags ? .on : .off
        
        clickableLinks.state = UserDefaultsManagement.clickableLinks ? .on : .off
        
        setCodeFontPreview()
        setNoteFontPreview()
    }

    //MARK: global variables

    let storage = Storage.shared()

    @IBAction func liveImagesPreview(_ sender: NSButton) {
        let editors = AppDelegate.getEditTextViews()
        
        for editor in editors {
            if UserDefaultsManagement.liveImagesPreview {
                if let note = editor.note, let storage = editor.textStorage, storage.length > 0 {
                    storage.setAttributedString(note.content)
                }
            }

            UserDefaultsManagement.liveImagesPreview = (sender.state == NSControl.StateValue.on)

            if let note = editor.note, let evc = editor.editorViewController, !editor.isPreviewEnabled() {
                NotesTextProcessor.highlight(note: note)
                evc.refillEditArea()
            }
        }
    }

    @IBAction func codeBlockHighlight(_ sender: NSButton) {
        UserDefaultsManagement.codeBlockHighlight = (sender.state == NSControl.StateValue.on)
        Storage.shared().resetCacheAttributes()

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

        Storage.shared().resetCacheAttributes()
        UserDefaultsManagement.codeTheme = item.title

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                editor.textStorage?.updateParagraphStyle()

                MPreviewView.template = nil
                NotesTextProcessor.resetCaches()

                evc.refillEditArea(force: true)
            }
        }
    }

    @IBAction func inEditorFocus(_ sender: NSButton) {
        UserDefaultsManagement.focusInEditorOnNoteSelect = (sender.state == .on)
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
                NotesTextProcessor.resetCaches()

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
            if let note = editor.note, let evc = editor.editorViewController {
                NotesTextProcessor.highlight(note: note)
                evc.disablePreview()
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
                NotesTextProcessor.resetCaches()

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
                NotesTextProcessor.resetCaches()
    
                evc.refillEditArea(force: true)
            }
        }
    }

    @IBAction func inlineTags(_ sender: NSButton) {
        UserDefaultsManagement.inlineTags = (sender.state == .on)

        guard let vc = ViewController.shared() else { return }

        Storage.shared().tags = []

        for note in Storage.shared().noteList {
            note.tags = []

            if UserDefaultsManagement.inlineTags {
                _ = note.scanContentTags()
            }
        }

        vc.sidebarOutlineView.reloadSidebar()
    }

    @IBAction func highlightIndentedCodeBlocks(_ sender: NSButton) {
        UserDefaultsManagement.indentedCodeBlockHighlighting = (sender.state == NSControl.StateValue.on)

        Storage.shared().resetCacheAttributes()
        
        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                evc.refillEditArea()
            }
        }
    }
    
    @IBAction func highlightLinks(_ sender: NSButton) {
        UserDefaultsManagement.clickableLinks = (sender.state == NSControl.StateValue.on)

        Storage.shared().resetCacheAttributes()
        
        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                evc.refillEditArea()
            }
        }
    }
    
    @IBAction func setCodeFont(_ sender: NSButton) {
        let fontManager = NSFontManager.shared
        fontManager.setSelectedFont(UserDefaultsManagement.codeFont, isMultiple: false)
        fontManager.orderFrontFontPanel(self)
        fontManager.target = self
        fontManager.action = #selector(changeCodeFont(_:))
    }
    
    @IBAction func setNoteFont(_ sender: NSButton) {
        let fontManager = NSFontManager.shared
        fontManager.setSelectedFont(UserDefaultsManagement.noteFont, isMultiple: false)
        fontManager.orderFrontFontPanel(self)
        fontManager.target = self
        fontManager.action = #selector(changeNoteFont(_:))
    }

    @IBAction func changeCodeFont(_ sender: Any?) {
        let fontManager = NSFontManager.shared
        let newFont = fontManager.convert(UserDefaultsManagement.codeFont)
        UserDefaultsManagement.codeFont = newFont
        NotesTextProcessor.codeFont = newFont
        
        ViewController.shared()?.reloadFonts()
        
        setCodeFontPreview()
    }

    @IBAction func changeNoteFont(_ sender: Any?) {
        let fontManager = NSFontManager.shared
        let newFont = fontManager.convert(UserDefaultsManagement.noteFont)
        UserDefaultsManagement.noteFont = newFont

        ViewController.shared()?.reloadFonts()

        setNoteFontPreview()
    }

    @IBAction func resetFont(_ sender: Any) {
        UserDefaultsManagement.fontName = nil
        UserDefaultsManagement.codeFontName = "Source Code Pro"

        ViewController.shared()?.reloadFonts()

        setCodeFontPreview()
        setNoteFontPreview()
    }

    private func setCodeFontPreview() {
        let familyName = UserDefaultsManagement.codeFont.familyName ?? "Source Code Pro"

        codeFontPreview.font = NSFont(name: familyName, size: 13)
        codeFontPreview.stringValue = "\(familyName) \(UserDefaultsManagement.codeFont.pointSize)pt"
    }

    private func setNoteFontPreview() {
        noteFontPreview.font = NSFont(name: UserDefaultsManagement.noteFont.fontName, size: 13)

        if let familyName = UserDefaultsManagement.noteFont.familyName {
            noteFontPreview.stringValue = "\(familyName) \(UserDefaultsManagement.noteFont.pointSize)pt"
        }
    }
}
