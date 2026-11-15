import Foundation

enum SharedInbox {
    static let fileExtensions: Set<String> = ["md", "txt", "fsclip"]
    static let didEnqueue = Notification.Name("co.fluder.FSNotes.share.didEnqueue")

    static func directory() throws -> URL {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "FSNotesShareGroup") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw CocoaError(.fileWriteNoPermission)
        }

        let directory = container.appendingPathComponent("Shared Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func noteTitle(from clip: URL) -> String {
        let name = clip.deletingPathExtension().lastPathComponent
        let suffixLength = 36
        guard name.count > suffixLength + 3,
              UUID(uuidString: String(name.suffix(suffixLength))) != nil,
              name.dropLast(suffixLength).hasSuffix(" - ") else { return name }
        return String(name.dropLast(suffixLength + 3))
    }

    struct Attachment {
        let name: String
        let data: Data
    }

    static func enqueue(attachments: [Attachment]) throws {
        guard let first = attachments.first else { return }
        let queue = try directory()
        let identifier = UUID().uuidString
        let staging = queue.appendingPathComponent("." + identifier, isDirectory: true)
        let files = FileManager.default
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: staging) }
        for (index, attachment) in attachments.enumerated() {
            let folder = staging.appendingPathComponent(String(index), isDirectory: true)
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = (attachment.name as NSString).lastPathComponent
            guard !name.isEmpty, name != ".", name != ".." else { throw CocoaError(.fileWriteInvalidFileName) }
            try attachment.data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
        let title = (first.name as NSString).deletingPathExtension
        // Publish only after every attachment has been written.
        let destination = queue.appendingPathComponent("\(safeName(title)) - \(identifier).fsclip")
        try files.moveItem(at: staging, to: destination)
        notify()
    }

    private static func notify() {
        DistributedNotificationCenter.default().postNotificationName(
            didEnqueue, object: nil, userInfo: nil, deliverImmediately: true
        )
    }

    private static func safeName(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        let title = title.components(separatedBy: invalid).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        var name = ""
        for character in title {
            if name.utf8.count + character.utf8.count > 210 { break }
            name.append(character)
        }
        return name.isEmpty ? NSLocalizedString("Shared Page", comment: "") : name
    }

    static func enqueue(title: String, text: String, asMarkdown: Bool) throws {
        let name = safeName(title)

        let file = try directory().appendingPathComponent("\(name) - \(UUID().uuidString)")
            .appendingPathExtension(asMarkdown ? "md" : "txt")
        try Data(text.utf8).write(to: file, options: .atomic)
        notify()
    }
}
