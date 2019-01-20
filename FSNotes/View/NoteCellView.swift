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

    public var tableView: NotesTableView? {
        get {
            guard let viewController = NSApp.windows.first?.contentViewController as? ViewController else {
                return nil
            }

            return viewController.notesTableView
        }
    }

    let labelColor = NSColor(deviceRed: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    let previewMaximumLineHeight: CGFloat = 12
    let previewLineSpacing: CGFloat = 1
    
    override func viewWillDraw() {
        if let originY = UserDefaultsManagement.cellViewFrameOriginY {
            adjustTopMargin(margin: originY)
        }

        super.viewWillDraw()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let fontName = UserDefaultsManagement.fontName
        date.font = NSFont(name: fontName, size: 10)
        renderPin()
        
        if (UserDefaultsManagement.horizontalOrientation) {
            preview.isHidden = true
        } else {
            preview.isHidden = false
        }

        adjustPinPosition()
        udpateSelectionHighlight()

        var margin = 0
        if !UserDefaultsManagement.horizontalOrientation {
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

        // vertically align
        let lineHeight = previewLineSpacing + previewMaximumLineHeight
        var numberOfLines = 0
        
        if !UserDefaultsManagement.horizontalOrientation && !UserDefaultsManagement.hidePreview {
            let minimumLineNumbers = Int(additionalHeight / lineHeight) - 1
            
            if minimumLineNumbers > 0 {
                numberOfLines = minimumLineNumbers
            }
            
            if (additionalHeight > 1 + CGFloat(Int(lineHeight) * (minimumLineNumbers + 1))) {
                numberOfLines = Int(additionalHeight / lineHeight)
            }
        }
                
        let frameY = (CGFloat(UserDefaultsManagement.cellSpacing) - CGFloat(numberOfLines) * CGFloat(lineHeight)) / 2
        
        // save margin
        if frameY >= 0 {
            let y = CGFloat(Int(frameY)) - 2
            adjustTopMargin(margin: y)
            UserDefaultsManagement.cellViewFrameOriginY = y
        }
        
        // apply font and max lines numbers
        applyPreviewAttributes(numberOfLines, color: color)
    }
    
    func applyPreviewAttributes(_ maximumNumberOfLines: Int = 1, color: NSColor) {
        let string = preview.stringValue
        let fontName = UserDefaultsManagement.noteFont.fontName
        guard let font = NSFont(name: fontName, size: 11) else { return }
            
        let textColor = color
        
        let textParagraph = NSMutableParagraphStyle()
        textParagraph.lineSpacing = previewLineSpacing
        textParagraph.maximumLineHeight = previewMaximumLineHeight
        
        let attribs = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: textColor,
            NSAttributedStringKey.paragraphStyle: textParagraph
        ]
        
        preview.attributedStringValue = NSAttributedString.init(string: string, attributes: attribs)
        preview.maximumNumberOfLines = maximumNumberOfLines
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
            pin.isHidden = !note.isPinned
        }
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

        if let viewController = NSApp.windows.first?.contentViewController as? ViewController,
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
                    if let note = objectValue as? Note, !note.isPinned {
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
