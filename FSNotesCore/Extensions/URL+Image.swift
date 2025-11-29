//
//  URL+Image.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.11.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation
import AVKit

extension URL {
    func getImageSize() -> CGSize {
        guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return .zero
        }

        var width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        var height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 0

        // Swap dimensions for rotated images
        if case 5...8 = orientation {
            swap(&width, &height)
        }

        return CGSize(width: width, height: height)
    }

   func getVideoSize() -> CGSize {
        guard let track = AVURLAsset(url: self).tracks(withMediaType: .video).first else {
            return .zero
        }

        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }

    func getMediaSize() -> CGSize {
        if isVideo {
            return getVideoSize()
        }

        return getImageSize()
    }

    func getBorderSize(maxWidth: CGFloat) -> CGSize {
        let size = getMediaSize()

        guard size.width > maxWidth else {
            return size
        }

        let scale = maxWidth / size.width
        let newHeight = size.height * scale

        return CGSize(width: maxWidth, height: newHeight)

    }
}
