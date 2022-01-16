//
//  UIApplication.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension UIApplication {

    static func getMain() -> MainViewController? {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.mainController
    }

    static func getVC() -> ViewController {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.listController
    }

    static func getEVC() -> EditorViewController {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.editorController
    }

    static func getPVC() -> PreviewViewController {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.previewController
    }

    class func getPresentedViewController() -> UIViewController? {
        var presentViewController = UIApplication.shared.keyWindow?.rootViewController
        while let pVC = presentViewController?.presentedViewController
        {
            presentViewController = pVC
        }

        return presentViewController
    }
}
