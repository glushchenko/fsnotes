//
//  EditorViewController+Search.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 14.01.2026.
//  Copyright © 2026 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit

extension EditorViewController {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        clearHighlights()
        guard !searchText.isEmpty else {
            updateCounterLabel()
            return
        }
        findRanges(text: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        nextResult()
    }

    func scrollToCurrent() {
        guard !searchRanges.isEmpty else { return }

        let range = searchRanges[currentSearchIndex]

        let layoutManager = editArea.layoutManager
        let textContainer = editArea.textContainer

        let targetGlyphRange = layoutManager.glyphRange(
            forCharacterRange: range,
            actualCharacterRange: nil
        )

        let extendedGlyphRange = NSRange(
            location: 0,
            length: targetGlyphRange.location + targetGlyphRange.length
        )

        layoutManager.ensureLayout(forGlyphRange: extendedGlyphRange)

        _ = layoutManager.boundingRect(
            forGlyphRange: targetGlyphRange,
            in: textContainer
        )

        editArea.selectedRange = range
        editArea.scrollRangeToVisible(range)

        updateCounterLabel()
    }

    func nextResult() {
        guard !searchRanges.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchRanges.count
        highlightAll()
        scrollToCurrent()
    }

    func prevResult() {
        guard !searchRanges.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchRanges.count) % searchRanges.count
        highlightAll()
        scrollToCurrent()
    }
    
    func highlightAll() {
        guard !searchRanges.isEmpty else { return }
        let textStorage = editArea.textStorage
        textStorage.beginEditing()
        
        clearHighlights()
        originalBackgrounds.removeAll()
        
        for (index, range) in searchRanges.enumerated() {
            let color = index == currentSearchIndex
                ? UIColor.systemOrange.withAlphaComponent(0.6)
                : UIColor.systemYellow.withAlphaComponent(0.4)
            
            let currentBg = textStorage.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? UIColor
            originalBackgrounds[range] = currentBg
            
            textStorage.addAttribute(.backgroundColor, value: color, range: range)
        }
        
        textStorage.endEditing()
    }

    func clearHighlights() {
        guard !originalBackgrounds.isEmpty else { return }
        
        let textStorage = editArea.textStorage
        textStorage.beginEditing()
        
        for (range, originalColor) in originalBackgrounds {
            if let color = originalColor {
                textStorage.addAttribute(.backgroundColor, value: color, range: range)
            } else {
                textStorage.removeAttribute(.backgroundColor, range: range)
            }
        }
        
        textStorage.endEditing()
        
        originalBackgrounds.removeAll()
    }

    func findRanges(text: String) {
        searchRanges.removeAll()
        currentSearchIndex = 0

        let nsText = editArea.text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)

        while true {
            let found = nsText.range(
                of: text,
                options: .caseInsensitive,
                range: searchRange
            )
            if found.location == NSNotFound { break }
            searchRanges.append(found)

            searchRange = NSRange(
                location: found.location + found.length,
                length: nsText.length - found.location - found.length
            )
        }

        highlightAll()
        
        if !searchRanges.isEmpty {
            scrollToCurrent()
        }
        
        updateCounterLabel()
    }
    
    func updateCounterLabel() {
        guard let counterLabel = counterLabel else { return }
        
        if searchRanges.isEmpty {
            counterLabel.text = ""
        } else {
            counterLabel.text = "\(currentSearchIndex + 1)/\(searchRanges.count)"
        }
    }
    
    func showSearch() {
        guard let note = editArea.note else { return }
        
        if note.previewState {
            togglePreview()
        }
        
        if searchToolbar == nil {
            setupSearchAccessory()
        }
        
        keyboardAnchor?.becomeFirstResponder()
        searchBar?.becomeFirstResponder()
        
        originalSelectedRange = editArea.selectedRange
    }

    func hideSearch() {
        keyboardAnchor?.resignFirstResponder()
        searchBar?.resignFirstResponder()

        searchToolbar = nil
        searchBar = nil
        counterLabel = nil
        
        keyboardAnchor?.removeFromSuperview()
        keyboardAnchor = nil
        
        clearHighlights()

        if let range = originalSelectedRange {
            editArea.selectedRange = range
        }
        
        addToolBar(textField: editArea, toolbar: getMarkdownToolbar())
    }

    @objc func editorSearch() {
        if searchBar != nil {
            hideSearch()
        } else {
            showSearch()
        }
    }
    
    func setupSearchAccessory() {
        keyboardAnchor = UITextField()
        keyboardAnchor?.isHidden = true
        view.addSubview(keyboardAnchor!)
        
        searchBar = UISearchBar()
        
        guard let searchBar = searchBar else { return }
        searchBar.delegate = self
        searchBar.placeholder = "Find"
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.searchBarStyle = .minimal
        searchBar.showsCancelButton = false
    
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.clearButtonMode = .never
        }
    
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        counterLabel = UILabel()
        guard let counterLabel = counterLabel else { return }
        counterLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        counterLabel.textColor = .secondaryLabel
        counterLabel.textAlignment = .center
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        counterLabel.setContentHuggingPriority(.required, for: .horizontal)
        counterLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        counterLabel.widthAnchor.constraint(equalToConstant: 45).isActive = true
        
        let prevButton = UIButton(type: .system)
        prevButton.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        prevButton.addTarget(self, action: #selector(prevTap), for: .touchUpInside)
        prevButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        
        let nextButton = UIButton(type: .system)
        nextButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextTap), for: .touchUpInside)
        nextButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeSearch), for: .touchUpInside)
        closeButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        
        let prev = UIBarButtonItem(customView: prevButton)
        let next = UIBarButtonItem(customView: nextButton)
        let close = UIBarButtonItem(customView: closeButton)

        let searchItem = UIBarButtonItem(customView: searchBar)
        let counterItem = UIBarButtonItem(customView: counterLabel)

        searchToolbar = UIToolbar()
        guard let searchToolbar = searchToolbar else { return }
        searchToolbar.items = [
            searchItem,
            counterItem,
            prev,
            next,
            close
        ]

        searchToolbar.sizeToFit()
        
        keyboardAnchor?.inputAccessoryView = searchToolbar
    }
    
    @objc func nextTap() {
        nextResult()
    }

    @objc func prevTap() {
        prevResult()
    }
    
    @objc func closeSearch() {
        clearHighlights()
        
        keyboardAnchor?.resignFirstResponder()
        searchBar?.resignFirstResponder()

        editArea.inputAccessoryView = nil
        editArea.reloadInputViews()
        
        searchToolbar = nil
        searchBar = nil
        counterLabel = nil
        
        keyboardAnchor?.removeFromSuperview()
        keyboardAnchor = nil
        
        self.addToolBar(textField: editArea, toolbar: self.getMarkdownToolbar())
    }
    
    func openSearchWithText(_ searchText: String) {
        showSearch()
        
        self.searchBar?.text = searchText
        self.findRanges(text: searchText)
    }
}
