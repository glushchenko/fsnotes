//
//  ViewController+Web.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.09.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa
import Shout

extension EditorViewController {
    
    public func getCurrentNote() -> Note? {
        return vcEditor?.note
    }
    
    @IBAction func removeWebNote(_ sender: NSMenuItem) {
        if !UserDefaultsManagement.customWebServer, let note = getCurrentNote() {
            ViewController.shared()?.deleteAPI(note: note, completion: {
                DispatchQueue.main.async {
                    ViewController.shared()?.notesTableView.reloadRow(note: note)
                }
            })
            return
        }
        
        guard let note = getCurrentNote(), let remotePath = note.uploadPath else { return }
        
        DispatchQueue.global().async {
            do {
                guard let ssh = self.getSSHResource() else { return }
                
                try ssh.execute("rm -r \(remotePath)")
                
                note.uploadPath = nil
                
                Storage.shared().saveUploadPaths()
                
                DispatchQueue.main.async {
                    ViewController.shared()?.notesTableView.reloadRow(note: note)
                }
            } catch {
                print(error, error.localizedDescription)
            }
        }
    }
        
    @IBAction func uploadWebNote(_ sender: NSMenuItem) {
        if !UserDefaultsManagement.customWebServer, let note = getCurrentNote() {
            ViewController.shared()?.createAPI(note: note, completion: { url in
                DispatchQueue.main.async {
                    ViewController.shared()?.notesTableView.reloadRow(note: note)
                    guard let url = url else { return }

                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                    pasteboard.setString(url.absoluteString, forType: NSPasteboard.PasteboardType.string)

                    NSWorkspace.shared.open(url)
                }
            })
            return
        }
        
        guard let note = getCurrentNote() else { return }
        
        let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Upload")
        try? FileManager.default.removeItem(at: dst)
        
        guard let localURL = MPreviewView.buildPage(for: note, at: dst, web: true),
              let sftpPath = UserDefaultsManagement.sftpPath,
              let web = UserDefaultsManagement.sftpWeb else { return }
        
        let latinName  = note.getLatinName()
        let remoteDir = "\(sftpPath)\(latinName)/"
        let resultUrl = web + latinName + "/"
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(web + latinName + "/", forType: .string)
        
        let images = note.content.getImagesAndFiles()

        DispatchQueue.global().async {
            do {
                guard let ssh = self.getSSHResource() else { return }
                
                try ssh.execute("mkdir -p \(remoteDir)")
                
                let zipURL = localURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(note.getLatinName())
                    .appendingPathExtension("zip")

                let sftp = try ssh.openSftp()
                
                // Upload index.html
                let remoteIndex = remoteDir + "index.html"
                
                _ = try ssh.execute("rm -r \(remoteIndex)")
                try sftp.upload(localURL: localURL, remotePath: remoteIndex)
                
                // Upload archive
                try? sftp.upload(localURL: zipURL, remotePath: remoteDir + note.getLatinName() + ".zip")
                
                // Upload images
                var imageDirCreationDone = false
                for image in images {
                    if image.path.startsWith(string: "http://") || image.path.startsWith(string: "https://") {
                        continue
                    }
                    
                    if !imageDirCreationDone {
                        try ssh.execute("mkdir -p \(remoteDir)/i")
                        imageDirCreationDone = true
                    }
                    
                    try? sftp.upload(localURL: image.url, remotePath: remoteDir + "i/" + image.url.lastPathComponent)
                }

                if #available(macOS 10.14, *) {
                    DispatchQueue.main.async {
                        ViewController.shared()?.sendNotification()
                        ViewController.shared()?.notesTableView.reloadRow(note: note)
                        
                        NSWorkspace.shared.open(URL(string: resultUrl)!)
                    }
                }
                
                print("Upload was successfull for note: \(note.title)")
                
                note.uploadPath = remoteDir
                
                Storage.shared().saveUploadPaths()
            } catch {
                print(error, error.localizedDescription)
            }
        }
    }
        
    private func getSSHResource() -> SSH? {
        let host = UserDefaultsManagement.sftpHost
        let port = UserDefaultsManagement.sftpPort
        let username = UserDefaultsManagement.sftpUsername
        let password = UserDefaultsManagement.sftpPassword
        let passphrase = UserDefaultsManagement.sftpPassphrase
        
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
        
        if password.count == 0, publicKeyURL == nil || publicKeyURL == nil {
            uploadError(text: "Please set private and public keys")
            return nil
        }
        
        do {
            let ssh = try SSH(host: host, port: port)
            
            if password.count > 0 {
                try ssh.authenticate(username: username, password: password)
            } else if let publicKeyURL = publicKeyURL, let privateKeyURL = privateKeyURL {
                try ssh.authenticate(username: username, privateKey: privateKeyURL.path, publicKey: publicKeyURL.path, passphrase: passphrase)
            }
            
            return ssh
        } catch {
            print(error, error.localizedDescription)
            
            return nil
        }
    }
    
    public func uploadError(text: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.informativeText = NSLocalizedString("Upload error", comment: "")
        alert.messageText = text
        alert.beginSheetModal(for: self.view.window!)
    }
    
    public func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = NSLocalizedString(message, comment: "")
            alert.messageText = NSLocalizedString("Web publishing error", comment: "")
            alert.beginSheetModal(for: self.view.window!) { (returnCode: NSApplication.ModalResponse) -> Void in }
        }
    }
}
