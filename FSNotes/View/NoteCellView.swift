//
//  NoteCellView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NoteCellView: NSTableCellView {

    @IBOutlet var name: NSTextField!
    @IBOutlet var preview: PreviewTextField!
    @IBOutlet var date: NSTextField!
    @IBOutlet var pin: NSImageView!
    
    @IBOutlet weak var imagePreview: NSImageView!
    @IBOutlet weak var imagePreviewSecond: NSImageView!
    @IBOutlet weak var imagePreviewThird: NSImageView!

    public var note: Note?
    public var contentLength: Int = 0
    public var timestamp: Int64?

    private let labelColor = NSColor(deviceRed: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    private var previewMaximumLineHeight: CGFloat = 12
    private let previewLineSpacing: CGFloat = 3

    public var tableView: NotesTableView? {
        get {
            guard let vc = ViewController.shared() else { return nil }
            
            return vc.notesTableView
        }
    }

    override func viewWillDraw() {
        if let originY = UserDefaultsManagement.cellViewFrameOriginY {
            adjustTopMargin(margin: originY)
        }

        super.viewWillDraw()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        renderPin()

        if (UserDefaultsManagement.horizontalOrientation) {
            preview.isHidden = true
        } else {
            preview.isHidden = false
        }

        if UserDefaultsManagement.hidePreviewImages {
            imagePreview.isHidden = true
            imagePreviewSecond.isHidden = true
            imagePreviewThird.isHidden = true
        }

        udpateSelectionHighlight()

        var margin = 0
        if !UserDefaultsManagement.horizontalOrientation && !UserDefaultsManagement.hidePreviewImages{
            margin = self.note?.getImagePreviewUrl()?.count ?? 0 > 0 ? 58 : 0
        }
        
        pin.frame.origin.y = CGFloat(-4) + CGFloat(UserDefaultsManagement.cellSpacing) + CGFloat(margin)
    }

    public func configure(note: Note) {
        self.note = note
    }
    
    func applyPreviewStyle(_ color: NSColor) {
        let additionalHeight = CGFloat(UserDefaultsManagement.cellSpacing)

        guard additionalHeight >= 0 else {
            applyPreviewAttributes(color: color)
            return
        }

        let fontName = UserDefaultsManagement.noteFont.fontName
        let previewFontSzie = CGFloat(UserDefaultsManagement.previewFontSize)
        guard let font = NSFont(name: fontName, size: previewFontSzie) else { return }
        self.previewMaximumLineHeight = font.lineHeightCustom

        // vertically align
        var numberOfLines = 0
        var frameY = 0

        if !UserDefaultsManagement.horizontalOrientation && !UserDefaultsManagement.hidePreview {
            var size = CGFloat(0)
            var i = -1

            while true {
                if size > additionalHeight - 8 {
                    break
                }

                i += 1
                if i == 1 {
                    size += previewMaximumLineHeight
                } else {
                    size += previewLineSpacing + previewMaximumLineHeight
                }
            }

            numberOfLines = i
        }

        if numberOfLines > 1 {
            frameY = Int(
                (additionalHeight - previewMaximumLineHeight * CGFloat(numberOfLines) - previewLineSpacing * CGFloat(numberOfLines - 1)) / 2
            )
        } else {
            let lines = numberOfLines > 0 ? numberOfLines : 0
            frameY = Int(
                (additionalHeight - previewMaximumLineHeight * CGFloat(lines)) / 2
            )
        }

        // save margin
        if frameY >= 0 {
            let y = CGFloat(Int(frameY))
            adjustTopMargin(margin: y)
            UserDefaultsManagement.cellViewFrameOriginY = y
        }


        // apply font and max lines numbers
        applyPreviewAttributes(numberOfLines, color: color)
    }
    
    func applyPreviewAttributes(_ maximumNumberOfLines: Int = 1, color: NSColor) {
        let string = preview.stringValue
        let fontName = UserDefaultsManagement.noteFont.fontName

        let previewFontSize = CGFloat(UserDefaultsManagement.previewFontSize)
        guard let font = NSFont(name: fontName, size: previewFontSize) else { return }

        let textColor = color
        
        let textParagraph = NSMutableParagraphStyle()
        textParagraph.lineSpacing = previewLineSpacing
        textParagraph.maximumLineHeight = previewMaximumLineHeight

        let attribs = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: textColor,
            NSAttributedStringKey.paragraphStyle: textParagraph
        ]

        if maximumNumberOfLines > 0 {
            preview.attributedStringValue = NSAttributedString.init(string: string, attributes: attribs)
            preview.maximumNumberOfLines = maximumNumberOfLines
        } else {
            preview.attributedStringValue = NSAttributedString()
            preview.maximumNumberOfLines = -1
        }
    }

    // This NoteCellView has multiple contained views; this method changes
    // these views' color when the cell is selected.
    override var backgroundStyle: NSView.BackgroundStyle {
        set {
            if let rowView = self.superview as? NSTableRowView {
                super.backgroundStyle = rowView.isSelected ? NSView.BackgroundStyle.dark : NSView.BackgroundStyle.light
            }
            self.udpateSelectionHighlight()
        }
        get {
            return super.backgroundStyle;
        }
    }
    
    public func udpateSelectionHighlight() {
        if ( self.backgroundStyle == NSView.BackgroundStyle.dark ) {
            applyPreviewStyle(NSColor.white)
            date.textColor = NSColor.white
            name.textColor = NSColor.white
        } else {
            applyPreviewStyle(labelColor)
            date.textColor = labelColor

            if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
                name.textColor = NSColor.init(named: NSColor.Name(rawValue: "mainText"))
            } else {
                name.textColor = NSColor.black
            }
        }
    }
    
    func renderPin() {
        if let value = objectValue, let note = value as? Note  {
            if note.isEncrypted() {
                let name = note.isUnlocked() ? "lock-open" : "lock-closed.png"
                pin.image = NSImage(named: NSImage.Name(rawValue: name))
                pin.isHidden = false
                pin.image?.size = NSSize(width: 14, height: 14)
            } else {
                pin.image = NSImage(named: NSImage.Name(rawValue: "pin"))
                pin.isHidden = !note.isPinned
            }
        }

        adjustPinPosition()
    }

    public func styleImageView(imageView: ImageView) {
        imageView.isHidden = false
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = Color.darkGray.cgColor
        imageView.layer?.cornerRadius = 4
    }

    public func getPreviewImage(imageUrl: URL, note: Note) -> Image? {
        if let image = getPreviewImage(url: imageUrl) {
            return image
        } else {
            guard let image =
                ImageAttachment.getImageAndCacheData(url: imageUrl, note: note)
                else { return nil }

            let size = CGSize(width: 70, height: 70)
            if let resized = image.crop(to: size) {
                savePreviewImage(url: imageUrl, image: resized)
                return resized
            }
        }

        return nil
    }

    public func attachTitleAndPreview(note: Note) {
        if note.project.firstLineAsTitle, let firstLine = note.firstLineTitle {
            self.name.stringValue = firstLine
            self.preview.stringValue = note.preview
        } else {
            self.preview.stringValue = note.getPreviewForLabel()
            self.name.stringValue = note.getTitleWithoutLabel()
        }

        if let viewController = ViewController.shared(),
            let sidebarItem = viewController.getSidebarItem(),
            let sort = sidebarItem.project?.sortBy,
            sort == .creationDate,
            let date = note.getCreationDateForLabel() {
            self.date.stringValue = date
        } else {
            self.date.stringValue = note.getDateForLabel()
        }
    }

    public func adjustPinPosition() {
        for constraint in self.constraints {
            if constraint.secondAttribute == .leading, let im = constraint.firstItem as? NSImageView {
                if im.identifier?.rawValue == "pin" {
                    if let note = objectValue as? Note, !note.showIconInList() {
                        constraint.constant = -17
                    } else {
                        constraint.constant = 3
                    }
                }
            }
        }
    }

    private func adjustTopMargin(margin: CGFloat) {
        for constraint in self.constraints {
            if constraint.secondAttribute == .top, let item = constraint.firstItem {
                if let firstItem = item as? NSImageView, firstItem.identifier?.rawValue == "pin" {
                    constraint.constant = margin - 1
                    continue
                }

                if item.isKind(of: NameTextField.self) {
                    constraint.constant = margin
                    continue
                }

                if let item = item as? NSTextField, item.identifier?.rawValue == "cellDate" {
                    constraint.constant = margin
                }
            }
        }
    }

    private func getCacheUrl(from url: URL) -> URL? {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent("Preview")

        if let filePath = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            return temporary.appendingPathComponent(filePath)
        }

        return nil
    }

    private func savePreviewImage(url: URL, image: Image) {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent("Preview")

        if !FileManager.default.fileExists(atPath: temporary.path) {
            try? FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false, attributes: nil)
        }

        if let url = getCacheUrl(from: url) {
            if let data = image.jpgData {
                try? data.write(to: url)
            }
        }
    }

    private func getPreviewImage(url: URL) -> Image? {
        if let url = getCacheUrl(from: url) {
            if let data = try? Data(contentsOf: url) {
                return Image(data: data)
            }
        }

        return nil
    }
}
