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
}
