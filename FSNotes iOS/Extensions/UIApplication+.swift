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
        let pageVC = UIApplication.shared.windows[0].rootViewController as! PageViewController

        return pageVC.orderedViewControllers[0] as! ViewController
    }

    static func getEVC() -> EditorViewController {
        let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController
        let viewController = pageController!.orderedViewControllers[1] as? UINavigationController
        let evc = viewController!.viewControllers[0] as! EditorViewController

        return evc
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
