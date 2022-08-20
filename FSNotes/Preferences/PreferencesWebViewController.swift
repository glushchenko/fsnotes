//
//  PreferencesWebViewController.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 20.08.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

class PreferencesWebViewController: NSViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 550, height: 512)
        
        host.stringValue = UserDefaultsManagement.sftpHost
        port.stringValue = UserDefaultsManagement.sftpPort
        path.stringValue = UserDefaultsManagement.sftpPath
        web.stringValue = UserDefaultsManagement.sftpWeb
        username.stringValue = UserDefaultsManagement.sftpUsername
        password.stringValue = UserDefaultsManagement.sftpPassword
    }

    @IBOutlet weak var host: NSTextField!
    @IBOutlet weak var port: NSTextField!
    @IBOutlet weak var path: NSTextField!
    @IBOutlet weak var web: NSTextField!
    @IBOutlet weak var username: NSTextField!
    @IBOutlet weak var password: NSSecureTextField!
    
    @IBAction func host(_ sender: NSTextField) {
        UserDefaultsManagement.sftpHost = sender.stringValue
    }
    
    @IBAction func port(_ sender: NSTextField) {
        UserDefaultsManagement.sftpPort = sender.stringValue
    }
    
    @IBAction func path(_ sender: NSTextField) {
        UserDefaultsManagement.sftpPath = sender.stringValue
    }
    
    @IBAction func web(_ sender: NSTextField) {
        UserDefaultsManagement.sftpWeb = sender.stringValue
    }
    
    @IBAction func username(_ sender: NSTextField) {
        UserDefaultsManagement.sftpUsername = sender.stringValue
    }
    
    @IBAction func password(_ sender: NSSecureTextField) {
        UserDefaultsManagement.sftpPassword = sender.stringValue
    }
    
    @IBAction func privateKey(_ sender: Any) {
        
    }
    
    @IBAction func test(_ sender: Any) {
        
    }
}
