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
    
    @IBOutlet weak var titleConstraint: NSLayoutConstraint!
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
        name.layer?.zPosition = 1000

        if let descriptor = date.font?.fontDescriptor {
            date.font = NSFont.init(descriptor: descriptor, size: 11)
        }

        date.layer?.backgroundColor = UserDataService.instance.isDark
            ? NSColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1.00).cgColor
            : NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.00).cgColor

        date.layer?.cornerRadius = 5
        date.layer?.zPosition = 1001
        date.textColor = UserDataService.instance.isDark ? NSColor.white : NSColor.gray
        date.isHidden = UserDefaultsManagement.hideDate
        titleConstraint.constant = UserDefaultsManagement.hideDate ? 0 : 5

        if (UserDefaultsManagement.horizontalOrientation) {
            preview.isHidden = true
        } else {
            preview.isHidden = false
        }

        if UserDefaultsManagement.hidePreviewImages || UserDefaultsManagement.horizontalOrientation {
            imagePreview.isHidden = true
            imagePreviewSecond.isHidden = true
            imagePreviewThird.isHidden = true
        }

        udpateSelectionHighlight()

        var margin = 0
        if !UserDefaultsManagement.horizontalOrientation && !UserDefaultsManagement.hidePreviewImages{

            self.note?.loadPreviewInfo()

            margin = self.note?.imageUrl?.count ?? 0 > 0 ? 58 : 0
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
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: textParagraph
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

            date.layer?.backgroundColor = NSColor(red: 0.36, green: 0.67, blue: 0.92, alpha: 1.00).cgColor

        } else {
            applyPreviewStyle(labelColor)
            date.layer?.backgroundColor = UserDataService.instance.isDark
                ? NSColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1.00).cgColor
                : NSColor(red: 0.92, green: 0.94, blue: 0.92, alpha: 1.00).cgColor

            date.textColor = labelColor

            if self.name.stringValue == "Untitled Note" {
                name.textColor = NSColor(red:0.41, green:0.42, blue:0.46, alpha:1.0)
                return
            }

            if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
                name.textColor = NSColor.init(named: "mainText")
            } else {
                name.textColor = NSColor.black
            }
        }
    }
    
    func renderPin() {
        if let value = objectValue, let note = value as? Note  {
            if note.isEncrypted() {
                let name = note.isUnlocked() ? "lock-open" : "lock-closed"
                pin.image = NSImage(named: name)
                pin.isHidden = false
                pin.image?.size = NSSize(width: 14, height: 14)
            } else {
                pin.image = NSImage(named: "pin")
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
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MainNotesList")

        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: false, attributes: nil)
        }

        if let cacheName = imageUrl.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)?.md5 {

            let file = tempURL.appendingPathComponent(cacheName)
            if FileManager.default.fileExists(atPath: file.path) {
                if let data = try? Data(contentsOf: file), let image = NSImage(data: data) {
                    return image
                }
            }

            do {
                let data = try Data(contentsOf: imageUrl)
                if let image = NSImage(data: data) {
                    let size = CGSize(width: 70, height: 70)

                    if let resized = image.crop(to: size) {
                        let jpegImageData = resized.jpgData
                        try? jpegImageData?.write(to: file, options: .atomic)
                        return resized
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }

        return nil
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
                    constraint.constant = margin
                    continue
                }

                if item.isKind(of: NameTextField.self) {
                    constraint.constant = margin + 1.5
                    continue
                }

                if let item = item as? NSTextField, item.identifier?.rawValue == "cellDate" {
                    constraint.constant = margin + 3.5
                }
            }
        }
    }

    public func fixTopConstraint(position: Int?, note: Note) {
        guard let tableView = tableView else { return }

        for constraint in self.constraints {
            if ["firstImageTop", "secondImageTop", "thirdImageTop"].contains(constraint.identifier) {
                let ident = constraint.identifier
                let height = position != nil ? tableView.tableView(tableView, heightOfRow: position!) : self.frame.height

                self.removeConstraint(constraint)
                var con = CGFloat(0)

                if note.getTitle() != nil {
                    con += self.name.frame.height
                }

                let isPreviewExist = note.preview.trim().count > 0
                if isPreviewExist {
                    con += 3 + self.preview.frame.height
                }

                var diff = (height - con - 48) / 2
                diff += con

                var imageLink: NSImageView?
                switch constraint.identifier {
                case "firstImageTop":
                    imageLink = self.imagePreview
                case "secondImageTop":
                    imageLink = self.imagePreviewSecond
                case "thirdImageTop":
                    imageLink = self.imagePreviewThird
                default:
                    imageLink = self.imagePreview
                }

                guard let firstItem = imageLink else { continue }

                let secondItem = isPreviewExist ? self.preview : self
                let secondAttribute: NSLayoutConstraint.Attribute = isPreviewExist ? .bottom : .top
                let constant = isPreviewExist ? 6 : diff
                let constr = NSLayoutConstraint(item: firstItem, attribute: .top, relatedBy: .equal, toItem: secondItem, attribute: secondAttribute, multiplier: 1, constant: constant)

                constr.identifier = ident
                self.addConstraint(constr)
            }
        }
    }

    public func attachHeaders(note: Note) {
        if let title = note.getTitle() {
            self.name.stringValue = title
            self.preview.stringValue = note.preview
        } else {
            self.name.stringValue = ""
            self.preview.stringValue = ""
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

        self.udpateSelectionHighlight()
    }
}
