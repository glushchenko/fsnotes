//
//  NoteCellView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class NoteCellView: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var preview: UILabel!
    @IBOutlet weak var pin: UIImageView!

    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var imagePreviewSecond: UIImageView!
    @IBOutlet weak var imagePreviewThird: UIImageView!

    private var note: Note?
    private var contentLength: Int = 0
    private var timestamp: Int64?

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

    func configure(note: Note) {
        self.note = note

        date.attributedText = NSAttributedString(string: getDate())

        title.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
        preview.mixedTextColor = MixedColor(normal: 0x7f8ea7, night: 0xd9dee5)
        
        pin.isHidden = !note.isPinned
        
        var imageName = ""
        if NightNight.theme == .night {
            imageName = "_white"
        }
        
        pin.image = UIImage(named: "pin\(imageName).png" )
        
        if let font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .headline)
                let scaledFont = fontMetrics.scaledFont(for: font)
                title.font = scaledFont
                date.font = scaledFont
            }
        }
    }

    public func loadImagesPreview() {
        guard let note = self.note else { return }

        let imageURLs = note.getImagePreviewUrl()
        if note.project.firstLineAsTitle, let firstLine = note.firstLineTitle {
            self.title.text = firstLine
            self.preview.text = note.preview
        } else {
            self.preview.text = note.getPreviewForLabel()
            self.title.text = note.getTitleWithoutLabel()
        }

        guard note.content.length != self.contentLength else { return }
        guard let tableView = self.superview as? NotesTableView else { return }

        self.contentLength = note.content.length
        self.note?.invalidateCache()

        self.imagePreview.image = nil
        self.imagePreview.isHidden = true
        self.imagePreviewSecond.image = nil
        self.imagePreviewSecond.isHidden = true
        self.imagePreviewThird.image = nil
        self.imagePreviewThird.isHidden = true

        DispatchQueue.global(qos: .userInteractive).async {
            let current = Date().toMillis()
            self.timestamp = current

            if let images = imageURLs {
                var resizedImages: [UIImage] = []

                for imageUrl in images {
                    if current != self.timestamp {
                        return
                    }
                    
                    if let image = ImageAttachment.getImageAndCacheData(url: imageUrl, note: note)?.resize(height: 70) {
                        let resized = image.croppedInRect(rect: CGRect(x: 0, y: 0, width: 70, height: 70))
                        resizedImages.append(resized)
                    }
                }

                DispatchQueue.main.async {
                    if current != self.timestamp {
                        return
                    }

                    for resized in resizedImages {
                        if self.imagePreview.image == nil {
                            self.imagePreview.image = resized

                            self.styleImageView(imageView: self.imagePreview)
                        } else if self.imagePreviewSecond.image == nil {
                            self.imagePreviewSecond.image = resized

                            self.styleImageView(imageView: self.imagePreviewSecond)
                        } else if self.imagePreviewThird.image == nil {
                            self.imagePreviewThird.image = resized

                            self.styleImageView(imageView: self.imagePreviewThird)
                        }
                    }
                }
            }
        }

        tableView.beginUpdates()
        tableView.endUpdates()
    }

    private func styleImageView(imageView: UIImageView) {
        imageView.isHidden = false
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.darkGray.cgColor
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
    }

    public func getDate() -> String {
        if let sidebarItem = UIApplication.getVC().sidebarTableView.getSidebarItem(),
            let sort = sidebarItem.project?.sortBy,
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
        reloadDate()
        layoutIfNeeded()
    }
}
