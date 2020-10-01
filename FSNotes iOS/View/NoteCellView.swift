//
//  NoteCellView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
import SwipeCellKit

class NoteCellView: SwipeTableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var preview: UILabel!
    @IBOutlet weak var pin: UIImageView!

    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var imagePreviewSecond: UIImageView!
    @IBOutlet weak var imagePreviewThird: UIImageView!

    public var note: Note?
    public var contentLength: Int = 0
    public var timestamp: Int64?

    public var tableView: NotesTableView? {
        get {
            return self.superview as? NotesTableView
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        imagePreview.image = nil
        imagePreviewSecond.image = nil
        imagePreviewThird.image = nil

        imagePreview.isHidden = true
        imagePreviewSecond.isHidden = true
        imagePreviewThird.isHidden = true
        
        contentLength = 0
        timestamp = nil

        note = nil
    }

    public func reLoad() {
        if let note = self.note {
            configure(note: note)
        }
    }

    func configure(note: Note) {
        self.note = note

        date.attributedText = NSAttributedString(string: getDate())

        title.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
        preview.mixedTextColor = MixedColor(normal: 0x7f8ea7, night: 0xd9dee5)
        
        if note.isEncrypted() {
            let name = note.isUnlocked() ? "padlock-unlocked-ios" : "padlock-locked-ios"
            pin.image = UIImage(named: name)
            pin.isHidden = false
        } else {
            var imageName = ""
            if NightNight.theme == .night {
                imageName = "_white"
            }

            pin.image = UIImage(named: "pin\(imageName).png" )
            pin.isHidden = !note.isPinned
        }

        if let font = UserDefaultsManagement.noteFont {
            let fontMetrics = UIFontMetrics(forTextStyle: .headline)
            let scaledFont = fontMetrics.scaledFont(for: font)
            title.font = scaledFont
            date.font = scaledFont
        }
    }

    public func getDate() -> String {
        if let sort = note?.project.sortBy,
            sort == .creationDate,
            let date = note?.getCreationDateForLabel()
        {
            return date
        }

        if let date = note?.getDateForLabel() {
            return date
        }

        return String()
    }

    public func reloadDate() {
        date.text = getDate()
    }

    public func updateView() {
        loadImagesPreview()

        if let note = self.note {
            attachHeaders(note: note)
        }

        reloadDate()
    }

    public func styleImageView(imageView: ImageView) {
        imageView.isHidden = false
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = Color.darkGray.cgColor
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
    }

    public func attachHeaders(note: Note) {
        if let title = note.getTitle() {
            self.title.text = title
            self.preview.text = note.preview
        } else {
            self.title.text = String()
            self.preview.text = String()
        }
    }

    public func getPreviewImage(imageUrl: URL, note: Note) -> Image? {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MainNotesList")

        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: false, attributes: nil)
        }

        if let cacheName = imageUrl.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)?.md5 {

            let file = tempURL.appendingPathComponent(cacheName)
            if FileManager.default.fileExists(atPath: file.path) {
                if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                    return image
                }
            }

            do {
                let data = try Data(contentsOf: imageUrl)
                if let image = UIImage(data: data) {
                    let size = CGRect(x: 0, y: 0, width: 70, height: 70)
                    if let resized = image.resize(height: 70)?.croppedInRect(rect: size) {
                        let jpegImageData = resized.jpegData(compressionQuality: 1)
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

    public func fixTopConstraint(position: Int?, note: Note) {
        guard let tableView = tableView else { return }

        for constraint in self.contentView.constraints {
            if ["firstImageTop", "secondImageTop", "thirdImageTop"].contains(constraint.identifier) {
                let ident = constraint.identifier

                let height = position != nil ? tableView.cellHeights[IndexPath(row: position!, section: 0)]! : self.frame.height

                self.contentView.removeConstraint(constraint)
                var con = CGFloat(0)

                if note.getTitle() != nil {
                    con += self.title.frame.height
                }

                let isPreviewExist = note.preview.trim().count > 0
                if isPreviewExist {
                    con += 5 + self.preview.frame.height
                }

                var diff = (height - con - 70) / 2
                diff += con

                var imageLink: UIImageView?
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

                let secondItem = isPreviewExist ? self.preview : self.contentView
                let secondAttribute: NSLayoutConstraint.Attribute = isPreviewExist ? .bottom : .top
                let constant = isPreviewExist ? 12 : diff
                let constr = NSLayoutConstraint(item: firstItem, attribute: .top, relatedBy: .equal, toItem: secondItem, attribute: secondAttribute, multiplier: 1, constant: constant)

                constr.identifier = ident
                self.contentView.addConstraint(constr)
            }
        }
    }
}
