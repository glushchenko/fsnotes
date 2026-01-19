//
//  Note+Preview.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 14.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension Note {
    func parseYAMLBlock() -> Bool {
        let nsText = content.string as NSString
        var success = false
        
        FSParser.yamlBlockRegex.matches(nsText as String, range: NSRange(location: 0, length: nsText.length)) { match in
            guard let yamlRange = match?.range(at: 1), yamlRange.location == 0 else { return }
            
            let yamlText = nsText.substring(with: yamlRange)
            
            if let (title, preview) = self.loadYaml(components: yamlText.components(separatedBy: .newlines)) {
                self.title = title
                self.preview = preview
                success = true
            }
        }
        
        return success
    }

    func prepareComponents(from text: String) -> [String] {
        let trimmed = (text as NSString).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmed
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let cleaned = line.replacingOccurrences(of: "^#+", with: "", options: .regularExpression)
                return cleaned.isEmpty ? nil : cleaned
            }
    }
    
    func getNonEmptyLines() -> [String] {
        let nsText = content.string as NSString
        let length = nsText.length
        var lines: [String] = []
        lines.reserveCapacity(10)
        
        var location = 0
        
        while lines.count < 10 && location < length {
            let remainingRange = NSRange(location: location, length: length - location)
            let range = nsText.rangeOfCharacter(from: .newlines, range: remainingRange)
            
            if range.location != NSNotFound {
                let lineLength = range.location - location
                
                if lineLength > 0 {
                    var line = nsText.substring(with: NSRange(location: location, length: lineLength))

                    if location == 0 {
                        line = line.trimMDSyntax()
                    }
                    
                    if !line.isEmpty {
                        lines.append(line)
                    }
                }
                
                location = range.location + range.length
            } else {
                let line = nsText.substring(from: location)
                if !line.isEmpty {
                    lines.append(line)
                }
                break
            }
        }
        
        return lines
    }
    
    func loadYaml(components: [String]) -> (String, String)? {
        var tripleMinus = 0
        var previewFragments = [String]()

        var titleRow = String()
        var previewRow = String()

        if components.first == "---", components.count > 1 {
            for string in components {
                if string == "---" {
                    tripleMinus += 1
                }

                let res = string.matchingStrings(regex: "^title: ([\"\'”“]?)([^\n]+)\\1$")

                if res.count > 0 {
                    titleRow = res[0][2].trim()
                }

                if tripleMinus > 1 {
                    previewFragments.append(string)
                }
            }
        }

        if previewFragments.count > 0 {
            let previewString = previewFragments
                .joined(separator: " ")
                .replacingOccurrences(of: "---", with: "")

            previewRow = getPreviewLabel(with: previewString)
        }

        if titleRow.count > 0 {
            return (titleRow, previewRow)
        }

        return nil
    }

    func loadTitleFromFileName() {
        let fileName = url.deletingPathExtension().pathComponents.last!
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "")

        self.title = fileName
    }
}
