//
//  SettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet weak var toolbar: UIToolbar!
    @IBAction func doneAction(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }
    
    override func viewDidLoad() {
        toolbar.clipsToBounds = true
        super.viewDidLoad()
    }
}

