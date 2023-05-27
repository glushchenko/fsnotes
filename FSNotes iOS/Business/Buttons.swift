//
//  Buttons.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class Buttons {
    public static func getRateUs(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(systemName: "heart"), style: .plain, target: target, action: selector)
    }

    public static func getAdd(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: target, action: selector)
    }

    public static func getDone(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: target, action: selector)
    }

    public static func getShare(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: target, action: selector)
    }

    public static func getCrop(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(systemName: "crop"), style: .plain, target: target, action: selector)
    }

    public static func getTrash(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: target, action: selector)
    }
}
