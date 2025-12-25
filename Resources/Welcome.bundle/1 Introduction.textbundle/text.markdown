# FSNotes 7

Hi everyone. Time really flies — it feels like just yesterday it was 2017 and the first FSNotes release, blink — and 9 years have already passed. In 2026, I’ve prepared a new batch of improvements and fixes.

This release includes 62 tasks that I managed to complete over the last six months. 50 feature requests were closed and 12 bugs were fixed. If I missed your request for one reason or another, I apologise — as an author, I sometimes see things differently. You can find the full list of completed items here:
https://github.com/glushchenko/fsnotes/milestone/5

In addition to your GitHub requests, I also have my own ideas and tasks — more about them below.

## UI

There is good news and bad news here. Let’s start with the good news: the app now follows Apple’s standards even more closely. Standard system colours and UI elements that fit naturally into the overall system design are used everywhere. The horizontal notes list is now a thing of the past. Over the years it became outdated and no longer fit well, especially after the sidebar was introduced. Yes, it was cool in nvALT, but we’re going our own way. Background and text color customisation were removed for the same reasons.

Below this text, a word and character counter now works. Below the notes list, there is a notes counter. When you select items, the counters are recalculated.

Shortcuts and menus for Notes and Folders have been unified. The same key combinations now work both in the sidebar and in the notes list.

Annoying bugs were fixed, such as images not loading in the notes list or previews being shown from a different note.

## Editor

### Performance

The editor now passes the Moby Dick test: https://github.com/glushchenko/fsnotes/issues/1607

This means you can load an entire book and edit it. I’m working on an old MacBook Pro 2018 (and NSTextView performs quite fast there), so on modern M1+ processors the editor should really fly.

Autocomplete has been redesigned for wiki links [[, tags #, and code blocks ```. After typing three backticks, programming language autocomplete is now available.

As you may have already noticed, headings now differ in size.

### New shortcuts

- `cmd + option + up/down` — move the current lines up and down
- `cmd + option + t `— clear completed task lists
- `cmd + option + b` — search for backlinks in the wiki database

Tags are now highlighted nicely even when they wrap onto new lines. The undo/redo system has been reworked, and the editor’s behaviour is now much more stable.

### New syntax highlighter

Previously, FSNotes used the highlight.js library for code highlighting, running in JavaScript and then bridged to Swift — a hack, I know. I rewrote highlight.js in Swift, and highlighting now works instantly, currently for the 30 most popular programming languages.

### Scroll Position Persistence

Both in preview mode and in the text editor, the scroll position is now remembered. For now, this works only within the current session; I’m looking forward to your feedback before taking it further.

## Other

Many of you repeatedly asked about search in preview mode — I put in the effort and implemented it for you. The new syntax highlighter can also highlight Mermaid diagrams. Small details, such as removing duplicates when auto-closing quotes or brackets, have been waiting a long time for this release and are now finally available as well.

Everyone who submitted reports and requests — please go to your tickets and close them if everything works:
https://github.com/glushchenko/fsnotes/milestone/5

If you like this app - please support development, buy the application in [Mac App Store](https://apps.apple.com/app/fsnotes/id1277179284) and [AppStore](https://apps.apple.com/app/fsnotes-manager/id1346501102) for mobile FSNotes experience.

Thank you for your feedback and support.

—
Oleksandr Hlushchenko
25.12.2025
Ukraine, Kharkiv 🎄

```
