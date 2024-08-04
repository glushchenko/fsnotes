//
//  SidebarTableCellView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 5/5/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class SidebarTableCellView: UITableViewCell {    
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var labelConstraint: NSLayoutConstraint!

    public var sidebarItem: SidebarItem?

    func configure(sidebarItem: SidebarItem) {
        self.sidebarItem = sidebarItem
        
        self.icon.constraints[1].constant = 21
        self.labelConstraint.constant = 11
        icon.image = sidebarItem.icon

        var font = UIFont.systemFont(ofSize: 15)

        if sidebarItem.type == .Project || 
            sidebarItem.type == .ProjectEncryptedLocked ||
            sidebarItem.type == .ProjectEncryptedUnlocked ||
            sidebarItem.type == .Tag {
            font = UIFont.systemFont(ofSize: 14)
        }

        let fontMetrics = UIFontMetrics(forTextStyle: .title3)
        font = fontMetrics.scaledFont(for: font)

        label.font = font
        label.text = sidebarItem.name
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.selectedBackgroundView?.backgroundColor = UIColor.currentSidebarCell
        self.selectedBackgroundView?.frame = CGRect(x: 0, y: 0, width: 5, height: 40)
    }
}
