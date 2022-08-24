//
//  PreferencesWebViewController.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 20.08.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa
import Shout

class PreferencesWebViewController: NSViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 550, height: 512)
        
        host.stringValue = UserDefaultsManagement.sftpHost
        port.stringValue = String(UserDefaultsManagement.sftpPort)
        path.stringValue = UserDefaultsManagement.sftpPath ?? ""
        web.stringValue = UserDefaultsManagement.sftpWeb ?? ""
        username.stringValue = UserDefaultsManagement.sftpUsername
        password.stringValue = UserDefaultsManagement.sftpPassword
        passphrase.stringValue = UserDefaultsManagement.sftpPassphrase
        
        if let accessData = UserDefaultsManagement.sftpAccessData,
            let bookmarks = NSKeyedUnarchiver.unarchiveObject(with: accessData) as? [URL: Data] {
            
            for bookmark in bookmarks {
                rsaPath.url = bookmark.key
                break
            }
        }
    }

    @IBOutlet weak var host: NSTextField!
    @IBOutlet weak var port: NSTextField!
    @IBOutlet weak var path: NSTextField!
    @IBOutlet weak var web: NSTextField!
    @IBOutlet weak var username: NSTextField!
    @IBOutlet weak var password: NSSecureTextField!
    @IBOutlet weak var rsaPath: NSPathControl!
    @IBOutlet weak var passphrase: NSSecureTextField!
    
    @IBAction func host(_ sender: NSTextField) {
        UserDefaultsManagement.sftpHost = sender.stringValue
    }
    
    @IBAction func port(_ sender: NSTextField) {
        if let port = Int32(sender.stringValue) {
            UserDefaultsManagement.sftpPort = port
        }
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
    
    @IBAction func passphrase(_ sender: NSSecureTextField) {
        UserDefaultsManagement.sftpPassphrase = sender.stringValue
    }
    
    @IBAction func privateKey(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseFiles = true
        openPanel.begin { (result) -> Void in
            if result == .OK {
                if openPanel.urls.count != 2 {
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.informativeText = NSLocalizedString("Please select private and public key", comment: "")
                    alert.runModal()
                    return
                }
                
                var bookmarks = [URL: Data]()
                for url in openPanel.urls {
                    do {
                        let data = try url.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        
                        bookmarks[url] = data
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                
                let data = NSKeyedArchiver.archivedData(withRootObject: bookmarks)
                UserDefaultsManagement.sftpAccessData = data
                
                self.rsaPath.url = openPanel.urls[0]
            }
        }
    }
    
    @IBAction func test(_ sender: Any) {
        var publicKeyURL: URL?
        var privateKeyURL: URL?
        
        if let accessData = UserDefaultsManagement.sftpAccessData,
            let bookmarks = NSKeyedUnarchiver.unarchiveObject(with: accessData) as? [URL: Data] {
            for bookmark in bookmarks {
                if bookmark.key.path.hasSuffix(".pub") {
                    publicKeyURL = bookmark.key
                } else {
                    privateKeyURL = bookmark.key
                }
            }
        }
        
        let host = UserDefaultsManagement.sftpHost
        let port = UserDefaultsManagement.sftpPort
        let username = UserDefaultsManagement.sftpUsername
        let passphrase = UserDefaultsManagement.sftpPassphrase
        
        guard let publicKeyURL = publicKeyURL, let privateKeyURL = privateKeyURL else { return }
        guard let ssh = try? SSH(host: host, port: port) else { return }
        
        let path = Bundle.main.path(forResource: "MPreview", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)

        guard let bundleResourceURL = bundle?.resourceURL
            else { return }
        
        let localJsDir = bundleResourceURL.appendingPathComponent("js", isDirectory: true)
        let localFontsDir = bundleResourceURL.appendingPathComponent("fonts", isDirectory: true)
        let localCssFile = bundleResourceURL.appendingPathComponent("main.css")
        
        let alert = NSAlert()

        do {
            guard let remoteDir = UserDefaultsManagement.sftpPath else { throw "Please enter remote path" }
            
            let remoteJsDir = "\(remoteDir)js/"
            let remoteFontsDir = "\(remoteDir)fonts/"
            
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: localJsDir.path) else { return }
            guard let fontFiles = try? FileManager.default.contentsOfDirectory(atPath: localFontsDir.path) else { return }
            
            try ssh.authenticate(username: username, privateKey: privateKeyURL.path, publicKey: publicKeyURL.path, passphrase: passphrase)
            
            _ = try? ssh.execute("mkdir -p \(remoteJsDir)")
            _ = try? ssh.execute("mkdir -p \(remoteFontsDir)")
            
            let sftp = try ssh.openSftp()
            
            for file in files {
                let localURL = localJsDir.appendingPathComponent(file)
                try? sftp.upload(localURL: localURL, remotePath: remoteJsDir + file)
            }
            
            for file in fontFiles {
                let localURL = localFontsDir.appendingPathComponent(file)
                try? sftp.upload(localURL: localURL, remotePath: remoteFontsDir + file)
            }
            
            try? sftp.upload(localURL: localCssFile, remotePath: remoteDir + "main.css")
            
            alert.alertStyle = .informational
            alert.messageText = NSLocalizedString("Connection established successfully 🤟", comment: "")
        } catch {
            alert.alertStyle = .critical
            alert.informativeText = error.localizedDescription
            alert.messageText = NSLocalizedString("SSH error", comment: "")
        }
        
        alert.beginSheetModal(for: self.view.window!)
    }
}

extension String: LocalizedError { // Adds error.localizedDescription to Error instances
    public var errorDescription: String? { return self }
}
