//
//  MiniPreviewCellView.swift
//  FSNotes
//
//  Apple Notes-style "card" cell for the notes list (MiniPreview mode).
//
//  Fully programmatic subclass of NoteCellView: it creates its own subviews
//  and assigns them to the inherited outlets (name, preview, date, pin), so
//  shared call sites (performReload, reloadDate, renderPin) keep working.
//  The weak image outlets are backed by retained offscreen dummies so shared
//  code paths never hit nil. NoteCellView.draw() is overridden without a
//  super call because storyboard-only outlets (titleConstraint) are nil here.
//

import Cocoa

class MiniPreviewCellView: NoteCellView {

    private let cardView = NSView()

    // Cells are reused across reloads; refreshed when preview prefs change.
    private var cardHeightConstraint: NSLayoutConstraint?

    // Strong backing for the weak inherited image outlets; never displayed.
    private var offscreenImageViews = [NSImageView]()

    private static var previewFontSize: CGFloat {
        return CGFloat(UserDefaultsManagement.miniPreviewFontSize)
    }
    private static let previewLineSpacing: CGFloat = 2
    private static var previewLines: Int {
        return UserDefaultsManagement.miniPreviewLines
    }
    private static let previewMaxChars = 1500
    private static let cardPadding: CGFloat = 10
    private static let cardCornerRadius: CGFloat = 8
    private static let sideMargin: CGFloat = 12
    private static let cardTopMargin: CGFloat = 6
    private static let titleSpacing: CGFloat = 8
    private static let dateSpacing: CGFloat = 2
    private static let bottomMargin: CGFloat = 10
    private static let dateFontSize: CGFloat = 11

    public static var cardHeight: CGFloat {
        let font = NSFont.systemFont(ofSize: previewFontSize)
        let textHeight = CGFloat(previewLines) * font.lineHeightCustom
            + CGFloat(previewLines - 1) * previewLineSpacing

        return ceil(textHeight) + cardPadding * 2
    }

    public static var rowHeight: CGFloat {
        let titleSize = CGFloat(UserDefaultsManagement.noteTitleFontSize)
        let titleFont = UserDefaultsManagement.boldNoteTitles
            ? NSFont.systemFont(ofSize: titleSize, weight: .semibold)
            : NSFont.systemFont(ofSize: titleSize)

        var height = cardTopMargin
            + cardHeight
            + titleSpacing
            + ceil(titleFont.lineHeightCustom)

        if !UserDefaultsManagement.hideDate {
            let dateFont = NSFont.systemFont(ofSize: dateFontSize)
            height += dateSpacing + ceil(dateFont.lineHeightCustom)
        }

        return height + bottomMargin
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    private func setupSubviews() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = MiniPreviewCellView.cardCornerRadius
        cardView.layer?.masksToBounds = true
        addSubview(cardView)

        let previewField = PreviewTextField(frame: .zero)
        configureLabel(previewField)
        previewField.alignment = .natural
        previewField.lineBreakMode = .byWordWrapping
        previewField.cell?.wraps = true
        previewField.cell?.truncatesLastVisibleLine = true
        previewField.maximumNumberOfLines = MiniPreviewCellView.previewLines
        previewField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        previewField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewField.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        cardView.addSubview(previewField)
        preview = previewField

        let titleField = NSTextField(frame: .zero)
        configureLabel(titleField)
        titleField.alignment = .center
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        addSubview(titleField)
        name = titleField

        let dateField = NSTextField(frame: .zero)
        configureLabel(dateField)
        dateField.alignment = .center
        dateField.lineBreakMode = .byClipping
        dateField.maximumNumberOfLines = 1
        addSubview(dateField)
        date = dateField

        let pinView = NSImageView(frame: .zero)
        pinView.translatesAutoresizingMaskIntoConstraints = false
        pinView.imageScaling = .scaleProportionallyDown
        pinView.isHidden = true
        addSubview(pinView)
        pin = pinView

        let dummies = [NSImageView(), NSImageView(), NSImageView()]
        offscreenImageViews = dummies
        imagePreview = dummies[0]
        imagePreviewSecond = dummies[1]
        imagePreviewThird = dummies[2]

        let sideMargin = MiniPreviewCellView.sideMargin
        let cardPadding = MiniPreviewCellView.cardPadding

        let cardHeight = cardView.heightAnchor.constraint(equalToConstant: MiniPreviewCellView.cardHeight)
        cardHeightConstraint = cardHeight

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: MiniPreviewCellView.cardTopMargin),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sideMargin),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sideMargin),
            cardHeight,

            previewField.topAnchor.constraint(equalTo: cardView.topAnchor, constant: cardPadding),
            previewField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: cardPadding),
            previewField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -cardPadding),
            previewField.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -cardPadding),

            titleField.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: MiniPreviewCellView.titleSpacing),
            titleField.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleField.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: sideMargin + 22),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -(sideMargin + 22)),

            dateField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: MiniPreviewCellView.dateSpacing),
            dateField.centerXAnchor.constraint(equalTo: centerXAnchor),
            dateField.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: sideMargin),
            dateField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -sideMargin),

            pinView.trailingAnchor.constraint(equalTo: titleField.leadingAnchor, constant: -4),
            pinView.centerYAnchor.constraint(equalTo: titleField.centerYAnchor),
            pinView.widthAnchor.constraint(equalToConstant: 14),
            pinView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func configureLabel(_ field: NSTextField) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.isScrollable = false
    }

    override func configure(note: Note) {
        super.configure(note: note)

        // renderPin() reads objectValue
        objectValue = note
    }

    override func attachHeaders(note: Note) {
        name.stringValue = note.getTitle() ?? ""
        date.stringValue = note.getDateForLabel()
        preview.stringValue = getCardPreviewText(note: note)

        applyCardStyle()
        renderPin()
        updateCardAppearance()
    }

    // Called by NotesTableView.performReload; card text has its own fixed style.
    override func applyPreviewStyle() {
        applyCardStyle()
    }

    // Intentionally empty, no super call: NoteCellView.draw() touches
    // storyboard-only outlets (titleConstraint) and mutates fonts and
    // constraints, which is not safe during the drawing pass (it corrupts
    // the Auto Layout engine). All card styling happens in attachHeaders
    // and the observers below; subviews and the card layer draw themselves.
    override func draw(_ dirtyRect: NSRect) {}

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateCardAppearance()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateCardAppearance()
    }

    private func getCardPreviewText(note: Note) -> String {
        var text = String(note.content.string.prefix(MiniPreviewCellView.previewMaxChars))

        // The first line is already shown as the note title below the card
        if note.getTitle() != nil, UserDefaultsManagement.firstLineAsTitle,
            let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }

        return text
            .stripMarkdownSyntax()
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyCardStyle() {
        let previewFont = NSFont.systemFont(ofSize: MiniPreviewCellView.previewFontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = MiniPreviewCellView.previewLineSpacing
        paragraph.lineBreakMode = .byTruncatingTail

        let previewBrightness = UserDefaultsManagement.miniPreviewTextBrightness
        let previewColor = previewBrightness < 1.0
            ? NSColor.labelColor.withAlphaComponent(CGFloat(previewBrightness))
            : NSColor.labelColor

        preview.attributedStringValue = NSAttributedString(
            string: preview.stringValue,
            attributes: [
                .font: previewFont,
                .paragraphStyle: paragraph,
                .foregroundColor: previewColor
            ]
        )
        preview.maximumNumberOfLines = MiniPreviewCellView.previewLines
        cardHeightConstraint?.constant = MiniPreviewCellView.cardHeight

        let titleSize = CGFloat(UserDefaultsManagement.noteTitleFontSize)
        name.font = UserDefaultsManagement.boldNoteTitles
            ? NSFont.systemFont(ofSize: titleSize, weight: .semibold)
            : NSFont.systemFont(ofSize: titleSize)

        let brightness = UserDefaultsManagement.notesListTextBrightness
        if brightness < 1.0 {
            name.textColor = NSColor(named: "mainText")?.withAlphaComponent(CGFloat(brightness))
        } else {
            name.textColor = .labelColor
        }

        date.font = NSFont.systemFont(ofSize: MiniPreviewCellView.dateFontSize)
        date.textColor = .secondaryLabelColor
        date.isHidden = UserDefaultsManagement.hideDate
    }

    private func updateCardAppearance() {
        guard let layer = cardView.layer else { return }

        layer.backgroundColor = NSColor.textColor.withAlphaComponent(0.04).cgColor

        let isRowSelected = (superview as? NSTableRowView)?.isSelected == true
        if isRowSelected {
            layer.borderColor = NSColor.controlAccentColor.cgColor
            layer.borderWidth = 2
        } else {
            layer.borderColor = NSColor.separatorColor.cgColor
            layer.borderWidth = 1
        }
    }
}
