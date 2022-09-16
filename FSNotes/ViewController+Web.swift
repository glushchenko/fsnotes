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
            saveAPIIds()
            return
        }
        
        guard let note = getCurrentNote(), let remotePath = note.uploadPath else { return }
        
        DispatchQueue.global().async {
            do {
                guard let ssh = self.getSSHResource() else { return }
                
                try ssh.execute("rm -r \(remotePath)")
                
                note.uploadPath = nil
                
                if UserDefaultsManagement.customWebServer {
                    self.saveUploadPaths()
                } else {
                    self.saveAPIIds()
                }
            } catch {
                print(error, error.localizedDescription)
            }
        }
    }
        
    @IBAction func uploadWebNote(_ sender: NSMenuItem) {
        if !UserDefaultsManagement.customWebServer {
            createAPI()
            saveAPIIds()
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
                    }
                }
                
                print("Upload was successfull for note: \(note.title)")
                
                note.uploadPath = remoteDir
                
                self.saveUploadPaths()
            } catch {
                print(error, error.localizedDescription)
            }
        }
    }
    
    public func saveUploadPaths() {
        let notes = Storage.sharedInstance().noteList.filter({ $0.uploadPath != nil })
        
        var bookmarks = [URL: String]()
        for note in notes {
            if let path = note.uploadPath, path.count > 1 {
                bookmarks[note.url] = path
            }
        }
        
        let data = NSKeyedArchiver.archivedData(withRootObject: bookmarks)
        UserDefaultsManagement.sftpUploadBookmarksData = data
    }
    
    public func restoreUploadPaths() {
        guard let data = UserDefaultsManagement.sftpUploadBookmarksData,
              let uploadBookmarks = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL: String] else { return }
        
        for bookmark in uploadBookmarks {
            if let note = storage.getBy(url: bookmark.key) {
                note.uploadPath = bookmark.value
            }
        }
    }
    
    public func saveAPIIds() {
        let notes = Storage.sharedInstance().noteList.filter({ $0.uploadPath != nil })
        
        var bookmarks = [URL: String]()
        for note in notes {
            if let path = note.apiId, path.count > 1 {
                bookmarks[note.url] = path
            }
        }
        
        let data = NSKeyedArchiver.archivedData(withRootObject: bookmarks)
        UserDefaultsManagement.apiBookmarksData = data
    }
    
    public func restoreAPIIds() {
        guard let data = UserDefaultsManagement.apiBookmarksData,
              let uploadBookmarks = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL: String] else { return }
        
        for bookmark in uploadBookmarks {
            if let note = storage.getBy(url: bookmark.key) {
                note.apiId = bookmark.value
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
        guard let note = getCurrentNote() else { return }
        
        let api = UserDefaultsManagement.apiPath
        let boundary = generateBoundaryString()
        let session = URLSession.shared
        let url = URL(string: "\(api)?method=delete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let privateKey = UserDefaultsManagement.uploadKey
        
        var parameters = ["key" : privateKey]
        if let noteId = note.apiId {
            parameters["note_id"] = noteId
        }
        
        do {
            request.httpBody = try createBody(with: parameters, filePathKey: "file", urls: [], boundary: boundary)
        } catch {
            print("Request creation: \(error)")
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
              print("Post Request Error: \(error.localizedDescription)")
              return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                print("Invalid Response received from the server")
                
                //if let data = data {
                //  print(String(data: data, encoding: .utf8))
                //}
                
                return
            }
            
            guard let responseData = data else { return }
            
            //print(String(data: responseData, encoding: .utf8))

            note.apiId = nil
            self.saveAPIIds()
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
        
        do {
            request.httpBody = try createBody(with: parameters, filePathKey: "file", urls: urls, boundary: boundary)
        } catch {
            print("Request creation: \(error)")
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
              print("Post Request Error: \(error.localizedDescription)")
              return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                print("Invalid Response received from the server")
                
//                if let data = data {
//                    print(String(data: data, encoding: .utf8))
//                }
                
                return
            }
            
            guard let responseData = data else {
              print("nil Data received from the server")
              return
            }
            
            //print(String(data: responseData, encoding: .utf8))

            do {
                let decoder = JSONDecoder()
                let api = try decoder.decode(APIResponse.self, from: responseData)
                
                if let noteId = api.id {
                    note.apiId = noteId
                    
                    let url = "\(web)\(noteId)/"
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                    pasteboard.setString(url, forType: NSPasteboard.PasteboardType.string)
                }
            } catch let error {
                print(error)
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
