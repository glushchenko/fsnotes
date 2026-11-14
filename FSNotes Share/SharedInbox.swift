import Foundation

enum SharedInbox {
    static let fileExtensions: Set<String> = ["md", "txt"]
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

    static func enqueue(title: String, text: String, asMarkdown: Bool) throws {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        let safeTitle = title.components(separatedBy: invalidCharacters).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        // Leave room for the queue identifier and extension, without splitting a character.
        var name = ""
        var length = 0
        for character in safeTitle {
            length += character.utf8.count
            if length > 210 { break }
            name.append(character)
        }
        if name.isEmpty { name = NSLocalizedString("Shared Page", comment: "") }

        let file = try directory().appendingPathComponent("\(name) - \(UUID().uuidString)")
            .appendingPathExtension(asMarkdown ? "md" : "txt")
        try Data(text.utf8).write(to: file, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            didEnqueue, object: nil, userInfo: nil, deliverImmediately: true
        )
    }
}
