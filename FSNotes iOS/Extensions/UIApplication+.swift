//
//  UIApplication.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension UIApplication {

    static func getVC() -> ViewController {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.listController
    }

    static func getEVC() -> EditorViewController {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.editorController
    }

    static func getNC() -> MainNavigationController? {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.mainController
    }
}
