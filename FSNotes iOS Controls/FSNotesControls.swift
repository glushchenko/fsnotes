import SwiftUI
import WidgetKit

@main
struct FSNotesControls: WidgetBundle {
    var body: some Widget {
        NewInboxNoteControl()
    }
}

struct NewInboxNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "co.fluder.mobile.FSNotes-iOS.new-inbox-note") {
            ControlWidgetButton(action: NewInboxNoteIntent(target: .inbox)) {
                Label("New Note", systemImage: "square.and.pencil")
            }
        }
        .displayName("New Inbox Note")
        .description("Create a note in your FSNotes Inbox.")
    }
}
