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
        let pc = UIApplication.shared.windows[0].rootViewController as! BasicViewController
        return pc.containerController.viewControllers[0] as! ViewController
    }

    static func getEVC() -> EditorViewController {
        let pc = UIApplication.shared.windows[0].rootViewController as! BasicViewController
        let nav = pc.containerController.viewControllers[1] as! UINavigationController
        return nav.viewControllers.first as! EditorViewController
    }

    static func getPVC() -> PreviewViewController? {
         let pc = UIApplication.shared.windows[0].rootViewController as! BasicViewController
         let nav = pc.containerController.viewControllers[2] as! UINavigationController
         return nav.viewControllers.first as? PreviewViewController
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
