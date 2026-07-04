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
    public var onDisclosureToggle: ((Project) -> Void)?
    public var onTagDisclosureToggle: ((FSTag) -> Void)?

    func configure(sidebarItem: SidebarItem) {
        self.sidebarItem = sidebarItem

        let depth = projectDepth(sidebarItem.project)
        iconLeadingConstraint?.constant = 15 + CGFloat(depth * 18)
        
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
        label.text = sidebarItem.tag?.name ?? sidebarItem.name

        configureDisclosure(for: sidebarItem)
    }

    private func configureDisclosure(for item: SidebarItem) {
        guard item.type != .Inbox else {
            accessoryView = nil
            return
        }

        let project = item.project
        let tag = item.tag
        let isProjectExpandable = project?.child.contains(where: { $0.settings.showInSidebar }) == true
        let isTagExpandable = tag?.isExpandable() == true

        guard isProjectExpandable || isTagExpandable else {
            accessoryView = nil
            return
        }

        let button = UIButton(type: .system)
        let isExpanded = project?.isExpanded ?? tag?.isExpanded ?? false
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        button.setImage(
            UIImage(systemName: imageName, withConfiguration: imageConfiguration),
            for: .normal
        )
        button.tintColor = .secondaryLabel
        button.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        button.accessibilityLabel = isExpanded
            ? NSLocalizedString("Collapse folder", comment: "Sidebar accessibility")
            : NSLocalizedString("Expand folder", comment: "Sidebar accessibility")
        button.addTarget(self, action: #selector(toggleDisclosure), for: .touchUpInside)
        accessoryView = button
    }

    @objc private func toggleDisclosure() {
        guard let item = sidebarItem,
              let button = accessoryView as? UIButton else { return }

        let isExpanded = item.project?.isExpanded ?? item.tag?.isExpanded ?? false
        let imageName = isExpanded ? "chevron.right" : "chevron.down"
        let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        button.setImage(
            UIImage(systemName: imageName, withConfiguration: imageConfiguration),
            for: .normal
        )
        if let project = item.project {
            onDisclosureToggle?(project)
        } else if let tag = item.tag {
            onTagDisclosureToggle?(tag)
        }
    }

    private var iconLeadingConstraint: NSLayoutConstraint? {
        contentView.constraints.first {
            ($0.firstItem as? UIImageView) === icon
                && $0.firstAttribute == .leading
        }
    }

    private func projectDepth(_ project: Project?) -> Int {
        if let tag = sidebarItem?.tag {
            var depth = 0
            var parent = tag.parent

            while parent != nil {
                depth += 1
                parent = parent?.parent
            }

            return depth
        }

        guard sidebarItem?.type == .Project
            || sidebarItem?.type == .ProjectEncryptedLocked
            || sidebarItem?.type == .ProjectEncryptedUnlocked else { return 0 }

        var depth = 0
        var parent = project?.parent
        var visited = Set<ObjectIdentifier>()

        while let current = parent,
              !current.isDefault,
              !current.isTrash,
              current.settings.showInSidebar {
            let identifier = ObjectIdentifier(current)
            guard !visited.contains(identifier) else { break }

            visited.insert(identifier)
            depth += 1
            parent = current.parent
        }

        return depth
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.selectedBackgroundView?.backgroundColor = UIColor.currentSidebarCell
        self.selectedBackgroundView?.frame = CGRect(x: 0, y: 0, width: 5, height: 40)
    }
}
