import Foundation

struct InboxWidgetSnapshot: Codable {
    static let kind = "co.fluder.mobile.FSNotes-iOS.inbox-summary"
    static let inboxURL = URL(string: "fsnotes://widget-inbox")!

    let inboxCount: Int
    let totalCount: Int
    let weekThresholds: [Date]

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.es.fsnot.user.defaults")?
            .appendingPathComponent("InboxWidgetSnapshot.json")
    }

    static func read() -> Self? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func write() throws -> Bool {
        guard let fileURL = Self.fileURL else { return false }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        guard data != (try? Data(contentsOf: fileURL)) else { return false }

        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return true
    }
}
