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
            self.frame.origin.y = originY
        }

        super.viewWillDraw()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let fontName = UserDefaultsManagement.fontName
        date.font = NSFont(name: fontName, size: 10)
        renderPin()
        
        if (UserDefaultsManagement.horizontalOrientation) {
            applyHorizontalConstrains()
        } else {
            applyVerticalConstrainst()
        }
        
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
            let y = CGFloat(Int(frameY))
            self.frame.origin.y = y
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
    
    func applyVerticalConstrainst() {
        preview.translatesAutoresizingMaskIntoConstraints = false
        date.translatesAutoresizingMaskIntoConstraints = false
        name.translatesAutoresizingMaskIntoConstraints = false
        pin.translatesAutoresizingMaskIntoConstraints = true
        
        preview.isHidden =  false
        
        let previewTop = preview.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 4)
        let previewLeft = preview.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 5)
        let previewRight = preview.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -3)
        let dateRight = date.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -5)
        let dateTop = date.topAnchor.constraint(equalTo: self.topAnchor, constant: -1)
        let nameRight = name.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -60)
        let nameTop = name.topAnchor.constraint(equalTo: self.topAnchor, constant: -2)
        let nameLeft = name.leftAnchor.constraint(equalTo: pin.rightAnchor, constant: 3)
        
        NSLayoutConstraint.activate([previewTop, previewLeft, previewRight, dateRight, dateTop, nameLeft, nameRight, nameTop])
    }
    
    func applyHorizontalConstrains() {
        preview.translatesAutoresizingMaskIntoConstraints = false
        date.translatesAutoresizingMaskIntoConstraints = false
        name.translatesAutoresizingMaskIntoConstraints = false
        
        preview.isHidden =  true
        
        let dateRight = date.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -10)
        let dateTop = date.topAnchor.constraint(equalTo: self.topAnchor, constant: -2)
        let nameTop = name.topAnchor.constraint(equalTo: self.topAnchor, constant: -2)
        let nameLeft = name.leftAnchor.constraint(equalTo: pin.rightAnchor, constant: 5)
        let nameRight = name.rightAnchor.constraint(equalTo: date.leftAnchor, constant: -7)
        
        NSLayoutConstraint.activate([dateRight, dateTop,  nameLeft, nameRight, nameTop])
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

            if note.isPinned {
                pin.frame.size.width = 23
            } else {
                pin.frame.size.width = 0
            }
        }
    }

    public func styleImageView(imageView: ImageView) {
        imageView.isHidden = false
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = Color.darkGray.cgColor
        imageView.layer?.cornerRadius = 4
    }

    public func getPreviewImage(imageUrl: URL, note: Note) -> Image? {
        if let image = ImageAttachment.getPreviewImage(url: imageUrl) {
            return image
        } else {
            guard let image =
                ImageAttachment.getImageAndCacheData(url: imageUrl, note: note)
                else { return nil }

            let size = CGSize(width: 70, height: 70)
            if let resized = image.crop(to: size) {
                ImageAttachment.savePreviewImage(url: imageUrl, image: resized)
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
}
