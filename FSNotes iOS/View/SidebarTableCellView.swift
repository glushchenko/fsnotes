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
        
        if sidebarItem.type == .Category || sidebarItem.type == .Tag {
            label.frame.origin.x = 6
            let constraint = icon.constraints[1]
            constraint.constant = 0
        } else {
            icon.image = sidebarItem.icon
        }

        var font = UIFont(name: "HelveticaNeue", size: 15)

        if sidebarItem.type == .Category || sidebarItem.type == .Tag {
            font = UIFont(name: "HelveticaNeue-Bold", size: 14)
        }

        if #available(iOS 11.0, *) {
            if font != nil {
                let fontMetrics = UIFontMetrics(forTextStyle: .title3)
                font = fontMetrics.scaledFont(for: font!)
            }
        }
        
        label.font = font

        var name = sidebarItem.name
        if sidebarItem.type == .Tag {
            name = "# \(sidebarItem.name)"
        }

        label.text = name
        label.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        //label.alpha = 0.7
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let item = sidebarItem, item.type == .Category || item.type == .Tag  {
            self.selectedBackgroundView?.mixedBackgroundColor = MixedColor(normal: 0xcfdef2, night: 0x686372)
            self.selectedBackgroundView?.frame = CGRect(x: 0, y: 0, width: 5, height: 40)
        } else {
            self.selectionStyle = .none
        }
    }
}
