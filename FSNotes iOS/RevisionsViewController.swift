//
//  RevisionsViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 14.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

class RevisionsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var bottomSafeView: UIView!
    @IBOutlet weak var revisionsTable: UITableView!

    public var note: Note?
    private var revisions = [Revision]()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.barTintColor = UIColor.sidebar
        navigationBar.tintColor = UIColor.mainTheme
        navigationBar.backgroundColor = UIColor.sidebar
        bottomSafeView.backgroundColor = UIColor.sidebar

        if let urls = note?.listRevisions() {
            revisions = urls
        }

        revisionsTable.delegate = self
        revisionsTable.dataSource = self

        initButtons()
    }

    private func initButtons() {
        var buttons = [UIBarButtonItem]()

        let leftString = NSLocalizedString("Cancel", comment: "")
        navItem.leftBarButtonItem = UIBarButtonItem(title: leftString, style: .plain, target: self, action: #selector(closeController))

        if let project = note?.project, !project.hasRepository() {
            let dropImage = UIImage(systemName: "trash")
            let dropBarButton = UIBarButtonItem(image: dropImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(dropRevisions))

            buttons.append(dropBarButton)
        }

        let saveImage = UIImage(systemName: "plus.circle")
        let saveBarButton = UIBarButtonItem(image: saveImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(saveRevision))
        buttons.append(saveBarButton)

        navItem.rightBarButtonItems = buttons
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
        guard let note = note else { return }
        
        UIApplication.getVC().notesTable.saveRevisionAction(note: note)

        dismiss(animated: true)
    }

    @IBAction func closeController() {
        dismiss(animated: true)
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
        let revision = revisions[indexPath.row]
        note?.restore(revision: revision)

        UIApplication.getEVC().refill()

        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }

        headerView.textLabel?.font = .preferredFont(forTextStyle: .title1, compatibleWith: nil)
    }
}
