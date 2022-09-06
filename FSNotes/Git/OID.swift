//
//  OID.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 11/17/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Cgit2

/// An identifier for a Git object.
public struct OID {

	// MARK: - Initializers

	/// Create an instance from a hex formatted string.
	///
	/// string - A 40-byte hex formatted string.
	public init?(string: String) {
		// libgit2 doesn't enforce a maximum length
		if string.lengthOfBytes(using: String.Encoding.ascii) > 40 {
			return nil
		}

		let pointer = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
		let result = git_oid_fromstr(pointer, string)

		if result < GIT_OK.rawValue {
			pointer.deallocate()
			return nil
		}

		oid = pointer.pointee
		pointer.deallocate()
	}

	/// Create an instance from a libgit2 `git_oid`.
	public init(_ oid: git_oid) {
		self.oid = oid
	}

	// MARK: - Properties

	public var oid: git_oid
}

extension OID: CustomStringConvertible {
	public var description: String {
		let length = Int(GIT_OID_RAWSZ) * 2
		let string = UnsafeMutablePointer<Int8>.allocate(capacity: length)
		var oid = self.oid
		git_oid_fmt(string, &oid)

		return String(bytesNoCopy: string, length: length, encoding: .ascii, freeWhenDone: true)!
	}
}

extension OID: Hashable {
	public func hash(into hasher: inout Hasher) {
		withUnsafeBytes(of: oid.id) {
			hasher.combine(bytes: $0)
		}
	}

	public static func == (lhs: OID, rhs: OID) -> Bool {
		var left = lhs.oid
		var right = rhs.oid
		return git_oid_cmp(&left, &right) == 0
	}
}
