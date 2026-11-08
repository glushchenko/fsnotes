import SwiftUI
import WidgetKit

struct InboxWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: InboxWidgetSnapshot.kind, provider: InboxWidgetProvider()) { entry in
            InboxWidgetView(entry: entry)
        }
        .configurationDisplayName("Inbox Summary")
        .description("See how many notes are in your Inbox and how many have been there for at least a week.")
        .supportedFamilies([.systemSmall])
    }
}

private struct InboxWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: InboxWidgetSnapshot?

    var olderCount: Int {
        snapshot?.weekThresholds.count(where: { $0 <= date }) ?? 0
    }
}

private struct InboxWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> InboxWidgetEntry {
        let now = Date()
        let sample = InboxWidgetSnapshot(
            inboxCount: 12,
            totalCount: 384,
            weekThresholds: Array(repeating: now, count: 4)
        )
        return InboxWidgetEntry(date: now, snapshot: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (InboxWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : InboxWidgetEntry(date: Date(), snapshot: InboxWidgetSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InboxWidgetEntry>) -> Void) {
        let snapshot = InboxWidgetSnapshot.read()
        let now = Date()
        let futureDates = Set(snapshot?.weekThresholds.filter { $0 > now } ?? []).sorted()
        let entries = ([now] + futureDates).map { InboxWidgetEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

private struct InboxWidgetView: View {
    let entry: InboxWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Inbox", systemImage: "tray")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .widgetAccentable()

            if let snapshot = entry.snapshot {
                if snapshot.inboxCount == 0 {
                    Text("Inbox is empty")
                        .font(.headline)
                } else {
                    Text(snapshot.inboxCount, format: .number)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityLabel(Text("Notes in Inbox: \(snapshot.inboxCount)"))

                    Text("\(entry.olderCount) in Inbox for 7+ days")
                        .font(.caption)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text("Total notes: \(snapshot.totalCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("Open FSNotes to load your Inbox summary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
        .widgetURL(InboxWidgetSnapshot.inboxURL)
    }
}
