//
//  DatePickerViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 01.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

class DatePickerViewController: UIViewController {
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var bottomSafeView: UIView!
    @IBOutlet weak var navItem: UINavigationItem!

    public var notes: [Note]?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.barTintColor = UIColor.sidebar
        navigationBar.tintColor = UIColor.mainTheme
        navigationBar.backgroundColor = UIColor.sidebar
        bottomSafeView.backgroundColor = UIColor.sidebar

        if #available(iOS 14.0, *) {
            datePicker.preferredDatePickerStyle = .inline
        }

        if let date = notes?.first?.creationDate {
            datePicker.date = date
        }

        initButtons()
    }

    @IBAction func saveDate(_ sender: Any) {
        guard let notes = self.notes else { return }

        for note in notes {
            _ = note.setCreationDate(date: datePicker.date)
        }

        DispatchQueue.main.async {
            UIApplication.getVC().notesTable.reloadRows(notes: notes)
        }

        self.notes = nil
        dismiss(animated: true)
    }

    @IBAction func closeController(_ sender: Any) {
        dismiss(animated: true)
    }

    private func initButtons() {
        let leftString = NSLocalizedString("Cancel", comment: "")
        navItem.leftBarButtonItem = UIBarButtonItem(title: leftString, style: .plain, target: self, action: #selector(closeController))

        let saveBarButton = UIBarButtonItem(title: NSLocalizedString("Update", comment: ""), style: .plain, target: self, action: #selector(saveDate))

        navItem.rightBarButtonItem = saveBarButton
    }
}
