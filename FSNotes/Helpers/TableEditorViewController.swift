//
//  TableEditorViewController.swift
//  FSNotes
//
//  Created on 2026-03-23.
//

import Cocoa

class TableEditorViewController: NSViewController {

    struct TableData {
        var headers: [String]
        var rows: [[String]]
    }

    private var colsStepper: NSStepper!
    private var rowsStepper: NSStepper!
    private var colsLabel: NSTextField!
    private var rowsLabel: NSTextField!
    private var gridContainer: NSScrollView!
    private var gridStack: NSStackView!

    private var numCols = 3
    private var numRows = 2
    private var cells: [[NSTextField]] = []

    // If set, we're editing an existing table
    var existingData: TableData?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 280))

        // -- Top controls --
        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 8
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(controlsStack)

        let colLabel = NSTextField(labelWithString: "Columns:")
        colsStepper = NSStepper()
        colsStepper.minValue = 1
        colsStepper.maxValue = 10
        colsStepper.integerValue = numCols
        colsStepper.target = self
        colsStepper.action = #selector(steppersChanged)
        colsLabel = NSTextField(labelWithString: "\(numCols)")
        colsLabel.alignment = .center
        colsLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let rowLabel = NSTextField(labelWithString: "Rows:")
        rowsStepper = NSStepper()
        rowsStepper.minValue = 1
        rowsStepper.maxValue = 20
        rowsStepper.integerValue = numRows
        rowsStepper.target = self
        rowsStepper.action = #selector(steppersChanged)
        rowsLabel = NSTextField(labelWithString: "\(numRows)")
        rowsLabel.alignment = .center
        rowsLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true

        controlsStack.addArrangedSubview(colLabel)
        controlsStack.addArrangedSubview(colsLabel)
        controlsStack.addArrangedSubview(colsStepper)
        controlsStack.addArrangedSubview(NSBox.separator())
        controlsStack.addArrangedSubview(rowLabel)
        controlsStack.addArrangedSubview(rowsLabel)
        controlsStack.addArrangedSubview(rowsStepper)

        // -- Grid --
        gridContainer = NSScrollView()
        gridContainer.hasVerticalScroller = true
        gridContainer.hasHorizontalScroller = false
        gridContainer.borderType = .bezelBorder
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(gridContainer)

        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            controlsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            controlsStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),

            gridContainer.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 8),
            gridContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            gridContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            gridContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        self.view = container

        if let data = existingData {
            numCols = max(data.headers.count, 1)
            numRows = max(data.rows.count, 1)
            colsStepper.integerValue = numCols
            rowsStepper.integerValue = numRows
            colsLabel.stringValue = "\(numCols)"
            rowsLabel.stringValue = "\(numRows)"
        }

        rebuildGrid()

        if let data = existingData {
            populateGrid(with: data)
        }
    }

    @objc private func steppersChanged() {
        numCols = colsStepper.integerValue
        numRows = rowsStepper.integerValue
        colsLabel.stringValue = "\(numCols)"
        rowsLabel.stringValue = "\(numRows)"
        rebuildGrid()
    }

    private func rebuildGrid() {
        gridStack?.removeFromSuperview()

        // Wrapper view that pins the stack to the top
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)

        cells = []

        // Header row (bold placeholder)
        let headerRow = makeRow(count: numCols, placeholder: "Header", isHeader: true)
        stack.addArrangedSubview(headerRow.stack)
        cells.append(headerRow.fields)

        // Data rows
        for _ in 0..<numRows {
            let row = makeRow(count: numCols, placeholder: "Cell", isHeader: false)
            stack.addArrangedSubview(row.stack)
            cells.append(row.fields)
        }

        // Pin stack to top-left of wrapper, fill width
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -4),
            wrapper.bottomAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 4),
        ])

        // Make each row fill the available width
        for arrangedView in stack.arrangedSubviews {
            arrangedView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        gridContainer.documentView = wrapper
        gridStack = stack

        let width = max(CGFloat(numCols) * 120 + 16, gridContainer.bounds.width - 20)
        wrapper.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
        wrapper.heightAnchor.constraint(greaterThanOrEqualToConstant: gridContainer.bounds.height).isActive = true
    }

    private func makeRow(count: Int, placeholder: String, isHeader: Bool) -> (stack: NSStackView, fields: [NSTextField]) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 2
        row.distribution = .fillEqually

        var fields: [NSTextField] = []
        for i in 0..<count {
            let field = NSTextField()
            field.placeholderString = "\(placeholder) \(i + 1)"
            field.font = isHeader ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
            row.addArrangedSubview(field)
            fields.append(field)
        }

        return (row, fields)
    }

    private func populateGrid(with data: TableData) {
        // Headers
        if cells.count > 0 {
            for (i, header) in data.headers.enumerated() where i < cells[0].count {
                cells[0][i].stringValue = header
            }
        }
        // Rows
        for (r, row) in data.rows.enumerated() where r + 1 < cells.count {
            for (c, value) in row.enumerated() where c < cells[r + 1].count {
                cells[r + 1][c].stringValue = value
            }
        }
    }

    // MARK: - Generate Markdown

    func generateMarkdown() -> String {
        guard !cells.isEmpty else { return "" }

        let headers = cells[0].map { $0.stringValue.isEmpty ? " " : $0.stringValue }
        let dataRows = Array(cells.dropFirst()).map { row in
            row.map { $0.stringValue.isEmpty ? " " : $0.stringValue }
        }

        // Calculate column widths
        var widths = headers.map { $0.count }
        for row in dataRows {
            for (i, cell) in row.enumerated() where i < widths.count {
                widths[i] = max(widths[i], cell.count)
            }
        }
        // Minimum width of 3 for separator
        widths = widths.map { max($0, 3) }

        // Build header
        let headerLine = "| " + headers.enumerated().map { i, h in
            h.padding(toLength: widths[i], withPad: " ", startingAt: 0)
        }.joined(separator: " | ") + " |"

        // Separator
        let sepLine = "| " + widths.map { String(repeating: "-", count: $0) }.joined(separator: " | ") + " |"

        // Data rows
        let rowLines = dataRows.map { row -> String in
            "| " + row.enumerated().map { i, cell in
                let w = i < widths.count ? widths[i] : cell.count
                return cell.padding(toLength: w, withPad: " ", startingAt: 0)
            }.joined(separator: " | ") + " |"
        }

        return ([headerLine, sepLine] + rowLines).joined(separator: "\n")
    }

    // MARK: - Parse Markdown Table

    static func parse(markdown: String) -> TableData? {
        let lines = markdown.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return nil }

        func parseCells(_ line: String) -> [String] {
            var s = line.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("|") { s = String(s.dropFirst()) }
            if s.hasSuffix("|") { s = String(s.dropLast()) }
            return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let headers = parseCells(lines[0])

        // Find separator line (contains only |, -, :, spaces)
        var dataStart = 1
        if lines.count > 1 {
            let sep = lines[1].trimmingCharacters(in: .whitespaces)
            if sep.range(of: #"^[\|\-\:\s]+$"#, options: .regularExpression) != nil {
                dataStart = 2
            }
        }

        let rows = lines[dataStart...].map { parseCells($0) }
        return TableData(headers: headers, rows: Array(rows))
    }

    // MARK: - Detect Table at Cursor

    static func tableRange(in storage: NSTextStorage, at location: Int) -> NSRange? {
        let string = storage.string as NSString
        guard location < string.length else { return nil }

        let lineRange = string.paragraphRange(for: NSRange(location: location, length: 0))
        let line = string.substring(with: lineRange).trimmingCharacters(in: .whitespaces)

        // Check if current line looks like a table row
        guard line.hasPrefix("|") && line.hasSuffix("|") else { return nil }

        // Expand upward
        var start = lineRange.location
        while start > 0 {
            let prevRange = string.paragraphRange(for: NSRange(location: start - 1, length: 0))
            let prevLine = string.substring(with: prevRange).trimmingCharacters(in: .whitespaces)
            if prevLine.hasPrefix("|") && prevLine.hasSuffix("|") {
                start = prevRange.location
            } else {
                break
            }
        }

        // Expand downward
        var end = NSMaxRange(lineRange)
        while end < string.length {
            let nextRange = string.paragraphRange(for: NSRange(location: end, length: 0))
            let nextLine = string.substring(with: nextRange).trimmingCharacters(in: .whitespaces)
            if nextLine.hasPrefix("|") && nextLine.hasSuffix("|") {
                end = NSMaxRange(nextRange)
            } else {
                break
            }
        }

        return NSRange(location: start, length: end - start)
    }
}

private extension NSBox {
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
