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
}
