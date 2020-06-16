//
//  Note.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 7/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import Foundation

public class CoreNote: UIDocument {
    var note: Note

    init(note: Note) {
        self.note = note
        super.init(fileURL: note.url)
    }

    public override func contents(forType typeName: String) throws -> Any {
        return note.getFileWrapper()
    }


    public override func load(fromContents contents: Any, ofType typeName: String?) throws {

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "es.fsnot.external.file.changed"), object: nil)

//
//        DispatchQueue.main.async {
//            UIApplication.getVC().cloudDriveManager?.resolveConflict(url: self.fileURL)
//        }
//
//        if typeName == "public.rtf" {
//            /**
//             TODO: Implement RTF reloading
//             **/
//            return
//        }
//
//        if typeName == "org.textbundle.package", let wrapper = contents as? FileWrapper {
//            if let infoWrapper = wrapper.fileWrappers?["info.json"], let jsonData = infoWrapper.regularFileContents,
//                let info = try? JSONDecoder().decode(TextBundleInfo.self, from: jsonData) {
//                let container: NoteContainer = info.version == 0x02 ? .textBundleV2 : .textBundle
//
//                let ext = NoteType.withUTI(rawValue: info.type).getExtension(for: container)
//                let fileName = "text.\(ext)"
//
//                if let markdownWrapper = wrapper.fileWrappers?[fileName] {
//                    if let data = markdownWrapper.regularFileContents, let content = String(data: data as Data, encoding: .utf8) {
//                        self.content = content
//                        updateView()
//                    }
//                }
//
//                return
//            }
//        }
//
//        if let data = contents as? Data, let content = String(data: data, encoding: .utf8) {
//            self.content = content
//            updateView()
//        }
    }

    public func updateView() {
//        DispatchQueue.main.async {
//            UIApplication.getVC().updateTableOrEditor(url: self.fileURL, content: self.content)
//        }
    }
}
