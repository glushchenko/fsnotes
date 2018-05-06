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

    func configure(note: Note) {
        title.attributedText = NSAttributedString(string: note.title)
        preview.attributedText = NSAttributedString(string: note.getPreviewForLabel())
        date.attributedText = NSAttributedString(string: note.getDateForLabel())

        title.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
        preview.mixedTextColor = MixedColor(normal: 0x7f8ea7, night: 0xd9dee5)

        pin.isHidden = !note.isPinned

        if let font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .headline)
                let scaledFont = fontMetrics.scaledFont(for: font)
                title.font = scaledFont
                date.font = scaledFont
            }
        }
    }
}
