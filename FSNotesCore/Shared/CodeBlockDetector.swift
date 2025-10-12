//
//  CodeBlockDetector.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.10.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation
import Cocoa

class CodeBlockDetector {

    static let shared = CodeBlockDetector()

    private let pattern: String
    private let regex: NSRegularExpression
    private var previousRanges: [NSRange] = []

    init() {
        self.pattern = "(?<=\\n|\\A)```[a-zA-Z0-9() \t]*\\n([\\s\\S]*?)\\n```(?=\\n|\\Z)"

        do {
            self.regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            fatalError("Invalid regex pattern: \(error)")
        }
    }

    public func findCodeBlocks(in textStorage: NSAttributedString, range searchRange: NSRange? = nil) -> [NSRange] {
        guard UserDefaultsManagement.codeBlockHighlight else { return [] }

        let rangeToSearch = searchRange ?? NSRange(location: 0, length: textStorage.length)
        return regex.matches(in: textStorage.string, options: [], range: rangeToSearch)
                    .map { $0.range }
    }

    public func codeBlocks(textStorage: NSMutableAttributedString, editedRange: NSRange, delta: Int, newRanges: [NSRange]?) -> CodeBlockRanges {
        let newRanges = newRanges ?? []
        let adjustedPreviousRanges = adjustPreviousRanges(for: editedRange, delta: delta)

        previousRanges = newRanges

        let completelyNewBlocks = findCompletelyNewBlocks(
            new: newRanges,
            adjusted: adjustedPreviousRanges
        )

        let blocksFromSplit = findBlocksFromSplit(
            new: newRanges,
            adjusted: adjustedPreviousRanges
        )

        let blocksFromMerge = findBlocksFromMerge(
            new: newRanges,
            adjusted: adjustedPreviousRanges
        )

        let expandedBlocks = findExpandedBlocks(
            new: newRanges,
            adjusted: adjustedPreviousRanges,
            excluding: completelyNewBlocks + blocksFromSplit + blocksFromMerge
        )

        let (editedBlock, editedParagraph) = findEditedBlock(
            in: newRanges,
            editedRange: editedRange,
            textStorage: textStorage,
            excluding: completelyNewBlocks + blocksFromSplit + blocksFromMerge
        )

        let addedBlocks = completelyNewBlocks + blocksFromSplit + blocksFromMerge + expandedBlocks

        let markdownRanges = findRangesBecameMarkdown(
            adjusted: adjustedPreviousRanges,
            new: newRanges
        )

        return CodeBlockRanges(
            code: addedBlocks,
            md: markdownRanges,
            edited: editedBlock,
            editedParagraph: editedParagraph
        )
    }

    // MARK: - Helper Methods

    private func adjustPreviousRanges(for editedRange: NSRange, delta: Int) -> [NSRange] {
        return previousRanges.compactMap { range -> NSRange? in
            let adjustedRange: NSRange

            if range.location >= editedRange.location {
                adjustedRange = NSRange(location: range.location + delta, length: range.length)
            } else if NSMaxRange(range) <= editedRange.location {
                adjustedRange = range
            } else {
                let newLength = range.length + delta
                adjustedRange = NSRange(location: range.location, length: max(0, newLength))
            }

            return adjustedRange.length > 0 ? adjustedRange : nil
        }
    }

    private func findCompletelyNewBlocks(
        new: [NSRange],
        adjusted: [NSRange]
    ) -> [NSRange] {
        return new.filter { newRange in
            !adjusted.contains { oldRange in
                NSIntersectionRange(oldRange, newRange).length > 0
            }
        }
    }

    private func findBlocksFromSplit(
        new: [NSRange],
        adjusted: [NSRange]
    ) -> [NSRange] {
        var result: [NSRange] = []

        for oldRange in adjusted {
            let overlappingBlocks = new.filter { newRange in
                NSIntersectionRange(oldRange, newRange).length > 0
            }

            if overlappingBlocks.count >= 2 {
                result.append(contentsOf: overlappingBlocks)
            }
        }

        return result
    }

    private func findBlocksFromMerge(
        new: [NSRange],
        adjusted: [NSRange]
    ) -> [NSRange] {
        return new.filter { newRange in
            let overlappingOldBlocks = adjusted.filter { oldRange in
                NSIntersectionRange(oldRange, newRange).length > 0
            }
            return overlappingOldBlocks.count >= 2
        }
    }

    private func findExpandedBlocks(
        new: [NSRange],
        adjusted: [NSRange],
        excluding: [NSRange]
    ) -> [NSRange] {
        return new.compactMap { newRange -> NSRange? in
            guard !excluding.contains(where: { NSEqualRanges($0, newRange) }) else {
                return nil
            }

            let containedOldBlocks = adjusted.filter { oldRange in
                NSLocationInRange(oldRange.location, newRange) &&
                NSLocationInRange(NSMaxRange(oldRange) - 1, newRange) &&
                !NSEqualRanges(oldRange, newRange)
            }

            guard containedOldBlocks.count == 1,
                  let oldBlock = containedOldBlocks.first,
                  newRange.length > oldBlock.length else {
                return nil
            }

            return newRange
        }
    }

    private func findEditedBlock(
        in ranges: [NSRange],
        editedRange: NSRange,
        textStorage: NSMutableAttributedString,
        excluding: [NSRange]
    ) -> (block: NSRange?, paragraph: NSRange?) {
        for range in ranges {
            guard !excluding.contains(where: { NSEqualRanges($0, range) }) else {
                continue
            }

            // Проверяем, что editedRange находится внутри блока
            let isInside = editedRange.length == 0
                ? NSLocationInRange(editedRange.location, range) || editedRange.location == NSMaxRange(range)
                : NSIntersectionRange(range, editedRange).length > 0

            guard isInside else {
                continue
            }

            let paragraphRange = (textStorage.string as NSString).paragraphRange(for: editedRange)
            let editedParagraph = NSIntersectionRange(paragraphRange, range)

            return (block: range, paragraph: editedParagraph)
        }

        return (block: nil, paragraph: nil)
    }

    private func findRangesBecameMarkdown(
        adjusted: [NSRange],
        new: [NSRange]
    ) -> [NSRange] {
        var result: [NSRange] = []

        for oldRange in adjusted {
            var uncoveredRanges: [NSRange] = [oldRange]

            for newRange in new {
                uncoveredRanges = uncoveredRanges.flatMap { uncovered -> [NSRange] in
                    let intersection = NSIntersectionRange(uncovered, newRange)

                    guard intersection.length > 0 else {
                        return [uncovered]
                    }

                    var fragments: [NSRange] = []

                    // Левый фрагмент
                    if intersection.location > uncovered.location {
                        fragments.append(NSRange(
                            location: uncovered.location,
                            length: intersection.location - uncovered.location
                        ))
                    }

                    // Правый фрагмент
                    if NSMaxRange(intersection) < NSMaxRange(uncovered) {
                        fragments.append(NSRange(
                            location: NSMaxRange(intersection),
                            length: NSMaxRange(uncovered) - NSMaxRange(intersection)
                        ))
                    }

                    return fragments
                }
            }

            result.append(contentsOf: uncoveredRanges)
        }

        return result
    }
}

struct CodeBlockRanges {
    var new: [NSRange]?
    var code: [NSRange]?
    var md: [NSRange]?
    var edited: NSRange?
    var editedParagraph: NSRange?
}
