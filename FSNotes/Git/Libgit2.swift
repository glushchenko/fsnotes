//
//  Libgit2.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 1/11/15.
//  Copyright (c) 2015 GitHub, Inc. All rights reserved.
//

import Cgit2

extension git_strarray {
	func filter(_ isIncluded: (String) -> Bool) -> [String] {
		return map { $0 }.filter(isIncluded)
	}

	func map<T>(_ transform: (String) -> T) -> [T] {
		return (0..<self.count).map {
			let string = String(validatingUTF8: self.strings[$0]!)!
			return transform(string)
		}
	}
}
