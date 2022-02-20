//
//  DatePickerViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 01.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit
import NightNight

class DatePickerViewController: UIViewController {
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var bottomSafeView: UIView!
    @IBOutlet weak var navItem: UINavigationItem!

    public var notes: [Note]?

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarBackground), name: NSNotification.Name(rawValue: NightNightThemeChangeNotification), object: nil)

        navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationBar.mixedTintColor = Colors.buttonText
        navigationBar.mixedBarTintColor = Colors.Header
        navigationBar.mixedBackgroundColor = Colors.Header
        bottomSafeView.mixedBackgroundColor = Colors.Header

        updateNavigationBarBackground()

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

    @objc public func updateNavigationBarBackground() {
        if #available(iOS 13.0, *) {
            var color = UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00)
            if NightNight.theme == .night {
                color = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            }

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }

    private func initButtons() {
        let leftString = NSLocalizedString("Cancel", comment: "")
        navItem.leftBarButtonItem = UIBarButtonItem(title: leftString, style: .plain, target: self, action: #selector(closeController))

        let saveImage = UIImage(named: "saveButton")?.resize(maxWidthHeight: 32)
        let saveBarButton = UIBarButtonItem(image: saveImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(saveDate))

        navItem.rightBarButtonItem = saveBarButton
    }
}
