//
//  CustomTextStorage+Images.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 10/2/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import AVKit

extension NSTextStorage {
    public func loadImage(attachment: NSTextAttachment, url: URL, range: NSRange) {
        EditTextView.imagesLoaderQueue.addOperation {
            guard let size = attachment.image?.size else { return }
            let scale = UIScreen.main.scale

            let retinaSize = CGSize(width: size.width * scale, height: size.height * scale)
            attachment.image = NoteAttachment.getImage(url: url, size: retinaSize)
            
            DispatchQueue.main.async {
                let manager = UIApplication.getEVC().editArea.layoutManager as NSLayoutManager
                manager.invalidateDisplay(forCharacterRange: range)
            }
        }
    }
}
