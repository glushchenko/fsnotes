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
    @IBOutlet weak var labelConstraint: NSLayoutConstraint!

    public var sidebarItem: SidebarItem?

    func configure(sidebarItem: SidebarItem) {
        self.sidebarItem = sidebarItem
        
        if sidebarItem.type == .Category || sidebarItem.type == .Tag {
            self.icon.constraints[1].constant = 0
            self.labelConstraint.constant = 0
            icon.image = nil
        } else {
            self.icon.constraints[1].constant = 21
            self.labelConstraint.constant = 11
            icon.image = sidebarItem.icon
        }

        var font = UIFont(name: "HelveticaNeue", size: 15)

        if sidebarItem.type == .Category {
            font = UIFont(name: "HelveticaNeue-Bold", size: 13)
        }

        if sidebarItem.type == .Tag {
            font = UIFont(name: "HelveticaNeue-BoldItalic", size: 13)
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
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.selectedBackgroundView?.mixedBackgroundColor = MixedColor(normal: 0xcfdef2, night: 0x686372)
        self.selectedBackgroundView?.frame = CGRect(x: 0, y: 0, width: 5, height: 40)
    }
}
