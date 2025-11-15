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
        return UIBarButtonItem(systemImageName: "heart", target: target, selector: selector)
    }

    public static func getAdd(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(systemImageName: "plus", target: target, selector: selector)
    }

    public static func getDone(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: target, action: selector)
    }

    public static func getShare(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(systemImageName: "square.and.arrow.up", target: target, selector: selector)
    }

    public static func getCrop(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(systemImageName: "crop", target: target, selector: selector)
    }

    public static func getTrash(target: Any, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(systemImageName: "trash", target: target, selector: selector)
    }
}
