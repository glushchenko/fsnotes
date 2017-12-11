//
//  Notifications.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 12/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class NotificationsController {
    static func syncProgress() {
        DispatchQueue.main.async {
            let progress = "\(Storage.instance.countSynced()) / \(Storage.instance.countTotal())"
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "onCountChange"), object: nil, userInfo: ["progress": progress])
        }
    }
    
    static func onStartSync() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "onStartSync"), object: nil, userInfo: nil)
        }
    }
    
    static func onFinishSync() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "onFinishSync"), object: nil, userInfo: nil)
        }
    }
}
