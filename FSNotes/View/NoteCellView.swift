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

    private var previewMaximumLineHeight: CGFloat = 12
    private let previewLineSpacing: CGFloat = 3

    public var imageKeys = [String]()
    
    public var tableView: NotesTableView? {
        get {
            guard let vc = ViewController.shared() else { return nil }
            
            return vc.notesTableView
        }
    }

    public static var pinImages = [String: NSImage]()
    public static var pinEncryptedImages = [String: NSImage]()
    public static var pinSharedImages = [String: NSImage]()

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        renderPin()
        name.layer?.zPosition = 1000

        if let descriptor = date.font?.fontDescriptor {
            date.font = NSFont.init(descriptor: descriptor, size: 11)
        }

        date.layer?.cornerRadius = 5
        date.layer?.zPosition = 1001
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

        applyPreviewStyle()

        if !UserDefaultsManagement.horizontalOrientation && !UserDefaultsManagement.hidePreviewImages{
            self.note?.loadPreviewInfo()
        }
    }

    public func configure(note: Note) {
        self.note = note
    }
    
    func applyPreviewStyle() {
        let additionalHeight = CGFloat(UserDefaultsManagement.cellSpacing)

        guard additionalHeight >= 0 else {
            applyPreviewAttributes()
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
        applyPreviewAttributes(numberOfLines)
    }
    
    func applyPreviewAttributes(_ maximumNumberOfLines: Int = 1) {
        let string = preview.stringValue
        let fontName = UserDefaultsManagement.noteFont.fontName

        let previewFontSize = CGFloat(UserDefaultsManagement.previewFontSize)
        guard let font = NSFont(name: fontName, size: previewFontSize) else { return }
        
        let textParagraph = NSMutableParagraphStyle()
        textParagraph.lineSpacing = previewLineSpacing
        textParagraph.maximumLineHeight = previewMaximumLineHeight

        let attribs = [
            NSAttributedString.Key.font: font,
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

    public func isSelected() -> Bool {
        if let rowView = self.superview as? NSTableRowView, rowView.isSelected, window?.firstResponder == superview?.superview {
            return true
        }

        return false
    }

    public func isAccentColorTint() -> Bool {
        if let rowView = self.superview as? NSTableRowView, !rowView.isSelected {
            return true
        }

        if let rowView = self.superview as? NSTableRowView, rowView.isSelected, window?.firstResponder == superview?.superview {
            return false
        }

        return true
    }

    func renderPin() {
        if let value = objectValue, let note = value as? Note  {
            if note.isPublished() {
                if #available(macOS 12.0, *), let image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) {
                    pin.image = image
                    pin.image?.isTemplate = true
                    pin.contentTintColor = .controlAccentColor
                } else {
                    pin.image = NSImage(named: "web")
                    pin.image?.isTemplate = true
                    pin.contentTintColor = .controlAccentColor
                    pin.image?.size = NSSize(width: 14, height: 14)
                }

                pin.isHidden = false
            } else if note.isEncrypted() {
                let systemName = note.isUnlocked() ? "lock.open" : "lock"
                if #available(macOS 12.0, *), let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) {
                    pin.image = image
                    pin.image?.isTemplate = true
                    pin.contentTintColor = .controlAccentColor
                } else {
                    let name = note.isUnlocked() ? "lock-open" : "lock-closed"
                    pin.image = NSImage(named: name)
                    pin.contentTintColor = .controlAccentColor
                    pin.image?.isTemplate = true
                    pin.image?.size = NSSize(width: 14, height: 14)
                }
                pin.isHidden = false
            } else {
                if #available(macOS 12.0, *), let image = NSImage(systemSymbolName: "pin", accessibilityDescription: nil) {
                    pin.image = image
                    pin.image?.isTemplate = true
                    pin.contentTintColor = .controlAccentColor
                } else {
                    pin.image = NSImage(named: "pin")
                    pin.image?.isTemplate = true
                    pin.contentTintColor = .controlAccentColor
                    pin.image?.size = NSSize(width: 20, height: 20)
                }

                pin.isHidden = !note.isPinned
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
                        constraint.constant = -25
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
            let sort = sidebarItem.project?.settings.sortBy,
            sort == .creationDate,
            let date = note.getCreationDateForLabel() {
            self.date.stringValue = date
        } else {
            self.date.stringValue = note.getDateForLabel()
        }
    }
}
