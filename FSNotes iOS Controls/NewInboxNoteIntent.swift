import AppIntents

struct NewInboxNoteIntent: OpenIntent {
    static let title: LocalizedStringResource = "New Inbox Note"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Destination")
    var target: NoteDestination

    init() {}

    init(target: NoteDestination) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if IOS_APP
        SceneDelegate.requestInboxNote()
        #endif
        return .result()
    }
}

enum NoteDestination: String, AppEnum {
    case inbox

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note Destination"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.inbox: "Inbox"]
}
