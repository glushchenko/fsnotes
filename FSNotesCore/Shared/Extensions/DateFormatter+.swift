//
//  DateFormatter+.swift
//  FSNotes
//
//  Created by Jeff Hanbury on 25/03/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public extension DateFormatter {
    public func formatDateForDisplay(_ date: Date) -> String {
        dateStyle = .short
        timeStyle = .none
        locale = NSLocale.autoupdatingCurrent
        return string(from: date)
    }

    public func formatTimeForDisplay(_ date: Date) -> String {
        dateStyle = .none
        timeStyle = .short
        locale = NSLocale.autoupdatingCurrent
        return string(from: date)
    }

    public func formatForDuplicate(_ date: Date) -> String {
        dateFormat = "yyyyMMddhhmmss"
        return string(from: date)
    }
}
