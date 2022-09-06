//
//  StringExtensions.swift
//  SwiftGit2
//
//  Created by Brandon Plank on 1/4/21.
//  Copyright © 2021 GitHub, Inc. All rights reserved.
//

import Foundation

extension Array where Iterator.Element == String {
	public func stringsToCStrings() -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>{
		let strings: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> = self.withUnsafeBufferPointer {
			let buffer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: $0.count + 1)
			let val = $0.map{
				$0.withCString(strdup)
			}
			buffer.initialize(from: val, count: 1)
			buffer[$0.count] = nil
			return buffer
		}
		return strings;
	}
}

extension String {
	public func stringToCString() -> UnsafePointer<CChar>? {
		return (self as NSString).utf8String
	}
}
