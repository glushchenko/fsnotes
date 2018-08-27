//
//  SidebarTableCellView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 5/5/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class SidebarTableCellView: UITableViewCell {    
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    public var sidebarItem: SidebarItem?
    
    func configure(sidebarItem: SidebarItem) {
        self.sidebarItem = sidebarItem
        
        if let image = sidebarItem.icon {
            icon.image = image
        }
        
        var font = UIFont(name: "Helvetica", size: 14)
        if #available(iOS 11.0, *) {
            if font != nil {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font!)
            }
        }
        
        label.font = font
        label.text = sidebarItem.name
        label.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
}
