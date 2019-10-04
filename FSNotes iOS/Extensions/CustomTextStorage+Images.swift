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

            attachment.image = ImageAttachment.getImage(url: url, size: size)
            
            DispatchQueue.main.async {
                let manager = UIApplication.getEVC().editArea.layoutManager as NSLayoutManager
                manager.invalidateDisplay(forCharacterRange: range)
            }
        }
    }
}
