//
//  SidebarTableView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 5/5/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

import UIKit
import NightNight
import AudioToolbox

@IBDesignable
class SidebarTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource  {

    @IBInspectable var startColor:   UIColor = .black { didSet { updateColors() }}
    @IBInspectable var endColor:     UIColor = .white { didSet { updateColors() }}
    @IBInspectable var startLocation: Double =   0.05 { didSet { updateLocations() }}
    @IBInspectable var endLocation:   Double =   0.95 { didSet { updateLocations() }}
    @IBInspectable var horizontalMode:  Bool =  false { didSet { updatePoints() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { updatePoints() }}

    var gradientLayer: CAGradientLayer { return layer as! CAGradientLayer }
    var sidebar: Sidebar?

    private var sections = ["", "", "", ""]
    public var viewController: ViewController?

    override class var layerClass: AnyClass { return CAGradientLayer.self }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePoints()
        updateLocations()
        updateColors()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.hasTags() ? 4 : 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sidebar = sidebar else { return 1 }
        
        switch section {
        case 0:
            return 4
        case 1:
            return sidebar.getProjects().count
        case 2:
            return sidebar.getTags().count
        case 3:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "sidebarCell", for: indexPath) as! SidebarTableCellView

        
        guard let sidebar = sidebar else { return cell }
        if let sidebarItem = sidebar.getByIndexPath(path: indexPath) {
            cell.configure(sidebarItem: sidebarItem)
            cell.contentView.setNeedsLayout()
            cell.contentView.layoutIfNeeded()
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.backgroundView?.backgroundColor = UIColor.clear

            var font: UIFont = UIFont.systemFont(ofSize: 15)

            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font)
            }

            view.textLabel?.font = font.bold()
            view.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.backgroundView?.backgroundColor = UIColor.clear
            
            var font: UIFont = UIFont.systemFont(ofSize: 15)
            
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font)
            }
            
            view.textLabel?.font = font.bold()
            view.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 37
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let view = self.viewController,
            let sidebar = self.sidebar,
            let sidebarItem = sidebar.getByIndexPath(path: indexPath)
        else { return }

        AudioServicesPlaySystemSound(1519)

        if sidebarItem.name == "Settings" {
            view.openSettings()
            return
        }
        
        view.currentFolder.text = sidebarItem.name

        if sidebarItem.isTrash() {
            let storage = Storage.sharedInstance()
            DispatchQueue.global().async {
                storage.reLoadTrash()

                DispatchQueue.main.async {
                    view.updateTable() {}
                }
            }
            return
        }

        view.updateTable() {}
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.clear
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)

        if let sidebarCell = cell as? SidebarTableCellView {
            if let sidebarItem = (cell as! SidebarTableCellView).sidebarItem, sidebarItem.type == .Tag || sidebarItem.type == .Category {
                sidebarCell.icon.constraints[1].constant = 0
                sidebarCell.labelConstraint.constant = 0
                sidebarCell.contentView.setNeedsLayout()
                sidebarCell.contentView.layoutIfNeeded()
            }
        }
    }

    private func hasTags() -> Bool {
        return Storage.sharedInstance().hasTags()
    }

    // MARK: Gradient settings
    func updatePoints() {
        if horizontalMode {
            gradientLayer.startPoint = diagonalMode ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint   = diagonalMode ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0.5)
        } else {
            gradientLayer.startPoint = diagonalMode ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint   = diagonalMode ? CGPoint(x: 1, y: 1) : CGPoint(x: 0.5, y: 1)
        }
    }

    func updateLocations() {
        gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
    }

    func updateColors() {
        if NightNight.theme == .night{
            let startNightTheme = UIColor(red:0.14, green:0.14, blue:0.14, alpha:1.0)
            let endNightTheme = UIColor(red:0.12, green:0.11, blue:0.12, alpha:1.0)

            gradientLayer.colors    = [startNightTheme.cgColor, endNightTheme.cgColor]
        } else {
            gradientLayer.colors    = [startColor.cgColor, endColor.cgColor]
        }
    }
    
}
