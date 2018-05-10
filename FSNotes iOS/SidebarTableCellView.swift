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
                
        label.font = UIFont(name: "Helvetica", size: 14)
        label.text = sidebarItem.name
        label.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
}
