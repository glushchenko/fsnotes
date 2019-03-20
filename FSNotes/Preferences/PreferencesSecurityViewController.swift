//
//  PreferencesSecurityViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesSecurityViewController: NSViewController {

    @IBOutlet weak var lockOnSleep: NSButton!
    @IBOutlet weak var lockOnScreenActivated: NSButton!
    @IBOutlet weak var lockWhenFastUser: NSButton!
    @IBOutlet weak var allowTouchID: NSButton!
    @IBOutlet weak var saveInKeychain: NSButton!

    override func viewDidLoad() {
        lockOnSleep.state = UserDefaultsManagement.lockOnSleep ? .on : .off
        lockOnScreenActivated.state = UserDefaultsManagement.lockOnSleep ? .on : .off
        lockWhenFastUser.state = UserDefaultsManagement.lockOnUserSwitch ? .on : .off
        allowTouchID.state = UserDefaultsManagement.allowTouchID ? .on : .off
        saveInKeychain.state = UserDefaultsManagement.savePasswordInKeychain ? .on : .off
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 450, height: 324)
    }

    @IBAction func openMasterPasswordWindow(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        if let controller = vc.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "MasterPasswordViewController")) as? MasterPasswordViewController {

            presentViewControllerAsSheet(controller)
        }
    }

    @IBAction func lockOnSleep(_ sender: NSButton) {
        UserDefaultsManagement.lockOnSleep = (sender.state == .on)
    }

    @IBAction func lockOnScreenActivated(_ sender: NSButton) {
        UserDefaultsManagement.lockOnScreenActivated = (sender.state == .on)
    }

    @IBAction func lockWhenSwitched(_ sender: NSButton) {
        UserDefaultsManagement.lockOnUserSwitch = (sender.state == .on)
    }

    @IBAction func allowTouchID(_ sender: NSButton) {
        UserDefaultsManagement.allowTouchID = (sender.state == .on)
    }

    @IBAction func saveInKeychain(_ sender: NSButton) {
        UserDefaultsManagement.savePasswordInKeychain = (sender.state == .on)
    }

}
