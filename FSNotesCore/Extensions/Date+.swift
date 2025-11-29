//
//  Date+.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension Date {
    func toMillis() -> Int64! {
        return Int64(self.timeIntervalSince1970 * 1000)
    }

    static func getCurrentFormattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"

        return dateFormatter.string(from: Date())
    }

    func string(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

    func removeNanoseconds() -> Date? {
        let calendar = Calendar.current

        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        return calendar.date(from: calendar.dateComponents(components, from: self))
    }

    func isGreaterThan(_ date: Date) -> Bool {
        guard let selfWithoutNanoseconds = self.removeNanoseconds(),
              let dateWithoutNanoseconds = date.removeNanoseconds() else {
            return false
        }
        return selfWithoutNanoseconds > dateWithoutNanoseconds
    }
}
