//
//  NSMutableAttributedString+.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/20/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

extension NSMutableAttributedString {
    public func loadCheckboxes() {
        while mutableString.contains("- [ ] ") {
            let range = mutableString.range(of: "- [ ] ")
            if length >= range.upperBound, let unChecked = AttributedBox.getUnChecked() {
                replaceCharacters(in: range, with: unChecked)
            }
        }
        
        while mutableString.contains("- [x] ") {
            let range = mutableString.range(of: "- [x] ")
            let parRange = mutableString.paragraphRange(for: range)
            
            if length >= range.upperBound, let checked = AttributedBox.getChecked() {
                addAttribute(.strikethroughColor, value: UIColor.blackWhite, range: parRange)
                
                replaceCharacters(in: range, with: checked)
            }
        }
    }
}
