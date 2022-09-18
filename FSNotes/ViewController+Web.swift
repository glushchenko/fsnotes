//
//  ViewController+Web.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.09.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa
import Shout

extension ViewController {
    
    @IBAction func removeWebNote(_ sender: NSMenuItem) {
        if !UserDefaultsManagement.customWebServer {
            deleteAPI()
            return
        }
        
        guard let note = getCurrentNote(), let remotePath = note.uploadPath else { return }
        
        DispatchQueue.global().async {
            do {
                guard let ssh = self.getSSHResource() else { return }
                
                try ssh.execute("rm -r \(remotePath)")
                
                note.uploadPath = nil
                
                self.storage.saveUploadPaths()
                
                DispatchQueue.main.async {
                    self.notesTableView.reloadRow(note: note)
                }
            } catch {
                print(error, error.localizedDescription)
            }
        }
    }
        
    @IBAction func uploadWebNote(_ sender: NSMenuItem) {
        if !UserDefaultsManagement.customWebServer {
            createAPI()
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
        
        let images = note.getAllImages()

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
                        let imageDirName = image.path.split(separator: "/")[0]
                    
                        try ssh.execute("mkdir -p \(remoteDir)/\(imageDirName)")
                        imageDirCreationDone = true
                    }
                    
                    try? sftp.upload(localURL: image.url, remotePath: remoteDir + image.path)
                }

                if #available(macOS 10.14, *) {
                    DispatchQueue.main.async {
                        self.sendNotification()
                        self.notesTableView.reloadRow(note: note)
                        
                        NSWorkspace.shared.open(URL(string: resultUrl)!)
                    }
                }
                
                print("Upload was successfull for note: \(note.title)")
                
                note.uploadPath = remoteDir
                
                self.storage.saveUploadPaths()
            } catch {
                print(error, error.localizedDescription)
            }
        }
    }
        
    private func getSSHResource() -> SSH? {
        let host = UserDefaultsManagement.sftpHost
        let username = UserDefaultsManagement.sftpUsername
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
        
        guard let publicKeyURL = publicKeyURL, let privateKeyURL = privateKeyURL else { return nil }
        guard let ssh = try? SSH(host: host) else { return nil }
        
        do {
            try ssh.authenticate(username: username, privateKey: privateKeyURL.path, publicKey: publicKeyURL.path, passphrase: passphrase)
        } catch {
            print(error, error.localizedDescription)
            
            return nil
        }
        
        return ssh
    }
    
    private func deleteAPI() {
        guard let note = getCurrentNote(),
              let noteId = note.apiId else { return }
        
        let api = UserDefaultsManagement.apiPath
        let boundary = generateBoundaryString()
        let session = URLSession.shared
        let url = URL(string: "\(api)?method=delete")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let key = UserDefaultsManagement.uploadKey
        let parameters = ["key" : key, "note_id": noteId]

        do {
            request.httpBody = try createBody(with: parameters, filePathKey: "file", urls: [], boundary: boundary)
        } catch {
            print("Request creation: \(error)")
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) && error == nil
            else {
                self.showAlert(message: "FSNotes server is down at this moment, please try later")
                return
            }
            
            guard let responseData = data else {
                self.showAlert(message: "Empty response")
              return
            }

            let decoder = JSONDecoder()
            if let api = try? decoder.decode(APIResponse.self, from: responseData) {
                if let msg = api.error {
                    self.showAlert(message: msg)
                } else if let _ = api.id {
                    note.apiId = nil
                    self.storage.saveAPIIds()
                    
                    self.notesTableView.reloadRow(note: note)
                }
            }
        }
          
        task.resume()
    }
    
    private func createAPI() {
        let web = UserDefaultsManagement.webPath
        let api = UserDefaultsManagement.apiPath
        
        guard let note = getCurrentNote() else { return }
        
        let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Upload")
        try? FileManager.default.removeItem(at: dst)
        
        guard let localURL = MPreviewView.buildPage(for: note, at: dst, web: true) else { return }
        
        let zipUrl = localURL.deletingLastPathComponent().appendingPathComponent(note.getLatinName()).appendingPathExtension("zip")
        let privateKey = UserDefaultsManagement.uploadKey
        
        var parameters = ["key" : privateKey]
        if let noteId = note.apiId {
            parameters["note_id"] = noteId
        }
        
        let boundary = generateBoundaryString()
        
        let method = note.apiId != nil ? "update" : "create"
        let url = URL(string: "\(api)?method=\(method)")!
        
        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var urls = [URL]()
        let items = note.getAllImages()
        
        for item in items {
            urls.append(item.url)
        }
        
        urls.append(localURL)
        urls.append(zipUrl)
        
        guard let body = try? createBody(with: parameters, filePathKey: "file", urls: urls, boundary: boundary) else { return }
        request.httpBody = body
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) && error == nil
            else {
                self.showAlert(message: "FSNotes server is down at this moment, please try later")
                return
            }
            
            guard let responseData = data else {
                self.showAlert(message: "Empty response")
              return
            }

            let decoder = JSONDecoder()
            if let api = try? decoder.decode(APIResponse.self, from: responseData) {
                if let msg = api.error {
                    self.showAlert(message: msg)
                } else if let noteId = api.id {
                    note.apiId = noteId
                    self.storage.saveAPIIds()
                    
                    let resultUrl = "\(web)\(noteId)/"
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                    pasteboard.setString(resultUrl, forType: NSPasteboard.PasteboardType.string)
                    
                    self.notesTableView.reloadRow(note: note)
                    
                    NSWorkspace.shared.open(URL(string: resultUrl)!)
                }
            }
        }
          
        task.resume()
    }
    
    private func createBody(with parameters: [String: String]? = nil, filePathKey: String, urls: [URL], boundary: String) throws -> Data {
        var body = Data()
        
        parameters?.forEach { (key, value) in
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        var i = 0
        for url in urls {
            i += 1
            
            let filename = url.lastPathComponent
            let data = try Data(contentsOf: url)
            
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"entity_\(i)\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: \(url.mimeType)\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        return body
    }

    private func generateBoundaryString() -> String {
        return "Boundary-\(UUID().uuidString)"
    }
    
    private func showAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = NSLocalizedString(message, comment: "")
            alert.messageText = NSLocalizedString("Web publishing error", comment: "")
            alert.beginSheetModal(for: self.view.window!) { (returnCode: NSApplication.ModalResponse) -> Void in }
        }
    }
}

extension URL {
    var mimeType: String {
        guard
            let identifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let mimeType = UTTypeCopyPreferredTagWithClass(identifier, kUTTagClassMIMEType)?.takeRetainedValue() as String?
        else {
            return "application/octet-stream"
        }

        return mimeType
    }
}

extension Data {
    mutating func append(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }
}

struct APIResponse: Codable {
    var id: String?
    var error: String?
}
