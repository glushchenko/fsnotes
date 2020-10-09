//
//  FuzzySearchHelper.swift
//  FSNotes
//
//  Created by Chen Guo on 2020/9/30.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

// Excerpted from https://github.com/objcio/S01E216-quick-open-optimizing-performance-part-2/blob/9a255bc38d18481e101bcbdb3c58d8bbc8bd3d55/QuickOpen/ContentView.swift

/*
MIT License

Copyright (c) 2019 objc.io

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

enum FuzzySearchHelper {
    static func search(_ needle: String, in strs: [String]) -> [String] {
        return
            strs
                .map({ Array($0.lowercased().utf8) })
                .testFuzzyMatch(needle.lowercased())
                .sorted(by: { $0.score > $1.score })
                .prefix(30)
                .compactMap({ (index, _, _) -> String? in
                    guard strs.indices.contains(index) else {
                        assertionFailure()
                        return nil
                    }
                    let str = strs[index]
                    if str.isEmpty {
                        return nil
                    } else {
                        return str
                    }
                })
    }
}

private struct Matrix<A> {
    var array: [A]
    let width: Int
    private(set) var height: Int
    init(width: Int, height: Int, initialValue: A) {
        array = Array(repeating: initialValue, count: width*height)
        self.width = width
        self.height = height
    }

    private init(width: Int, height: Int, array: [A]) {
        self.width = width
        self.height = height
        self.array = array
    }

    subscript(column: Int, row: Int) -> A {
        get { array[row * width + column] }
        set { array[row * width + column] = newValue }
    }

    subscript(row row: Int) -> Array<A> {
        return Array(array[row * width..<(row+1)*width])
    }

    func map<B>(_ transform: (A) -> B) -> Matrix<B> {
        Matrix<B>(width: width, height: height, array: array.map(transform))
    }

    mutating func insert(row: Array<A>, at rowIdx: Int) {
        assert(row.count == width)
        assert(rowIdx <= height)
        array.insert(contentsOf: row, at: rowIdx * width)
        height += 1
    }

    func inserting(row: Array<A>, at rowIdx: Int) -> Matrix<A> {
        var copy = self
        copy.insert(row: row, at: rowIdx)
        return copy
    }
}

private extension Array where Element == [UInt8] {
    func testFuzzyMatch(_ needle: String) -> [(index: Int, string: [UInt8], score: Int)] {
        let n = Array<UInt8>(needle.utf8)
        var result: [(index: Int, string: [UInt8], score: Int)] = []
        let resultQueue = DispatchQueue(label: "result")
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let chunkSize = self.count/cores
        DispatchQueue.concurrentPerform(iterations: cores) { ix in
            let start = ix * chunkSize
            let end = Swift.min(start + chunkSize, endIndex)
            let chunk: [(Int, [UInt8], Int)] = self[start..<end].enumerated().compactMap { (index, element) -> (Int, [UInt8], Int)? in
                guard let match = element.fuzzyMatch3(n) else { return nil }
                return (start + index, element, match.score)
            }
            resultQueue.sync {
                result.append(contentsOf: chunk)
            }
        }
        return result
    }
}

private extension Array where Element: Equatable {
    func fuzzyMatch3(_ needle: [Element]) -> (score: Int, matrix: Matrix<Int?>)? {
        guard needle.count <= count else { return nil }
        var matrix = Matrix<Int?>(width: self.count, height: needle.count, initialValue: nil)
        if needle.isEmpty { return (score: 0, matrix: matrix) }
        var prevMatchIdx:  Int = -1
        for row in 0..<needle.count {
            let needleChar = needle[row]
            var firstMatchIdx: Int? = nil
            let remainderLength = needle.count - row - 1
            for column in (prevMatchIdx+1)..<(count-remainderLength) {
                let char = self[column]
                guard needleChar == char else {
                    continue
                }
                if firstMatchIdx == nil {
                    firstMatchIdx = column
                }
                var score = 1
                if row > 0 {
                    var maxPrevious = Int.min
                    for prevColumn in prevMatchIdx..<column {
                        guard let s = matrix[prevColumn, row-1] else { continue }
                        let gapPenalty = (column-prevColumn) - 1
                        maxPrevious = Swift.max(maxPrevious, s - gapPenalty)
                    }
                    score += maxPrevious
                }
                matrix[column, row] = score
            }
            guard let firstIx = firstMatchIdx else { return nil }
            prevMatchIdx = firstIx
        }
        guard let score = matrix[row: needle.count-1].compactMap({ $0 }).max() else {
            return  nil
        }
        return (score, matrix)
    }
}
