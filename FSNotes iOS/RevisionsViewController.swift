//
//  RevisionsViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 14.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit
import NightNight

class RevisionsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var bottomSafeView: UIView!
    @IBOutlet weak var revisionsTable: UITableView!

    public var note: Note?
    private var revisions = [Revision]()

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarBackground), name: NSNotification.Name(rawValue: NightNightThemeChangeNotification), object: nil)

        navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationBar.mixedTintColor = Colors.buttonText
        navigationBar.mixedBarTintColor = Colors.Header
        navigationBar.mixedBackgroundColor = Colors.Header
        bottomSafeView.mixedBackgroundColor = Colors.Header

        updateNavigationBarBackground()

        if let urls = note?.listRevisions() {
            revisions = urls
        }

        revisionsTable.delegate = self
        revisionsTable.dataSource = self

        initButtons()
    }

    private func initButtons() {
        let leftString = NSLocalizedString("Cancel", comment: "")
        navItem.leftBarButtonItem = UIBarButtonItem(title: leftString, style: .plain, target: self, action: #selector(closeController))

        let dropImage = UIImage(named: "trashButton")?.resize(maxWidthHeight: 28)
        let dropBarButton = UIBarButtonItem(image: dropImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(dropRevisions))

        let saveImage = UIImage(named: "saveButton")?.resize(maxWidthHeight: 32)
        let saveBarButton = UIBarButtonItem(image: saveImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(saveRevision))

        navItem.rightBarButtonItems = [saveBarButton, dropBarButton]
    }

    @IBAction func dropRevisions() {
        let title = NSLocalizedString("Сlearing history", comment: "")
        let message = NSLocalizedString("Are you sure you want to delete all versions of this note?", comment: "")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "OK", style: .default) { (_) in
            self.note?.dropRevisions()
            self.dismiss(animated: true)
        })

        let cancel = NSLocalizedString("Cancel", comment: "")
            alert.addAction(UIAlertAction(title: cancel, style: .cancel, handler: { (action: UIAlertAction!) in
        }))

        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func saveRevision() {
        do {
            try note?.saveRevision()
        } catch {
            let alert = UIAlertController(title: "Git error", message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

            self.present(alert, animated: true, completion: nil)
            return
        }

        dismiss(animated: true)
    }

    @IBAction func closeController() {
        dismiss(animated: true)
    }

    @objc public func updateNavigationBarBackground() {
        if #available(iOS 13.0, *) {
            var color = UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00)
            if NightNight.theme == .night {
                color = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            }

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return revisions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        let date = Date(timeIntervalSince1970: revisions[indexPath.row].timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = DateFormatter.Style.medium //Set time style
        dateFormatter.dateStyle = DateFormatter.Style.medium //Set date style
        dateFormatter.timeZone = .current
        let localDate = dateFormatter.string(from: date)

        cell.textLabel?.text = localDate

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Saved versions", comment: "")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 100
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let url = revisions[indexPath.row].url {
            note?.restoreRevision(url: url)
        }

        UIApplication.getEVC().refill()

        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }

        headerView.textLabel?.font = .preferredFont(forTextStyle: .title1, compatibleWith: nil)
    }
}
