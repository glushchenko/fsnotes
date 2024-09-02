//
//  ViewController+WebApi.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 24.05.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

extension ViewController {
    public func deleteAPI(note: Note, completion: (() -> Void)? = nil) {
        guard let noteId = note.apiId else { return }

        let api = UserDefaultsManagement.apiPath
        let boundary = generateBoundaryString()
        let session = URLSession.shared
        let url = URL(string: "\(api)?method=delete")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let key = UserDefaultsManagement.uploadKey
        let parameters = ["key": key, "note_id": noteId]

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
                } else if api.id != nil {
                    note.apiId = nil
                    note.project.saveWebAPI()

                    completion?()
                }
            }
        }

        task.resume()
    }

    public func createAPI(note: Note, completion: ((_ url: URL?) -> Void)? = nil) {
        let web = UserDefaultsManagement.webPath
        let api = UserDefaultsManagement.apiPath

        let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Upload")
        try? FileManager.default.removeItem(at: dst)

        guard let localURL = MPreviewView.buildPage(for: note, at: dst, web: true) else { return }

        let zipUrl = localURL.deletingLastPathComponent().appendingPathComponent(note.getLatinName()).appendingPathExtension("zip")
        let privateKey = UserDefaultsManagement.uploadKey

        var parameters = ["key": privateKey]
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
                    note.project.saveWebAPI()

                    let resultUrl = "\(web)\(noteId)/"
                    let url = URL(string: resultUrl)!

                    completion?(url)
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

        var urlNum = 0
        for url in urls {
            urlNum += 1

            let filename = url.lastPathComponent
            let data = try Data(contentsOf: url)

            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"entity_\(urlNum)\"; filename=\"\(filename)\"\r\n")
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
