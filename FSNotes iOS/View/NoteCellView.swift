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
        if let note = self.note {
            attachTitleAndPreview(note: note)
        }
        loadImagesPreview()
        reloadDate()
        layoutIfNeeded()
    }

    public func styleImageView(imageView: ImageView) {
        imageView.isHidden = false
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = Color.darkGray.cgColor
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
    }

    public func attachTitleAndPreview(note: Note) {
        if note.project.firstLineAsTitle, let firstLine = note.firstLineTitle {
            self.title.text = firstLine
            self.preview.text = note.preview
        } else {
            self.preview.text = note.getPreviewForLabel()
            self.title.text = note.getTitleWithoutLabel()
        }
    }

    public func getPreviewImage(imageUrl: URL, note: Note) -> Image? {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())

        if let cacheName = imageUrl.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

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
                        let jpegImageData = UIImageJPEGRepresentation(resized, 1.0)
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
}
