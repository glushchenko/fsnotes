//
//  References.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 1/2/15.
//  Copyright (c) 2015 GitHub, Inc. All rights reserved.
//

import Cgit2

/// A reference to a git object.
public protocol ReferenceType {
	/// The full name of the reference (e.g., `refs/heads/master`).
	var longName: String { get }

	/// The short human-readable name of the reference if one exists (e.g., `master`).
	var shortName: String? { get }

	/// The OID of the referenced object.
	var oid: OID { get }
}

public extension ReferenceType {
	static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.longName == rhs.longName
			&& lhs.oid == rhs.oid
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(longName)
		hasher.combine(oid)
	}
}

/// Create a Reference, Branch, or TagReference from a libgit2 `git_reference`.
internal func referenceWithLibGit2Reference(_ pointer: OpaquePointer) -> ReferenceType {
	if git_reference_is_branch(pointer) != 0 || git_reference_is_remote(pointer) != 0 {
		return Branch(pointer)!
	} else if git_reference_is_tag(pointer) != 0 {
		return TagReference(pointer)!
	} else {
		return Reference(pointer)
	}
}

/// A generic reference to a git object.
public struct Reference: ReferenceType, Hashable {
	/// The full name of the reference (e.g., `refs/heads/master`).
	public let longName: String

	/// The short human-readable name of the reference if one exists (e.g., `master`).
	public let shortName: String?

	/// The OID of the referenced object.
	public let oid: OID

	/// Create an instance with a libgit2 `git_reference` object.
	public init(_ pointer: OpaquePointer) {
		let shorthand = String(validatingUTF8: git_reference_shorthand(pointer))!
		longName = String(validatingUTF8: git_reference_name(pointer))!
		shortName = (shorthand == longName ? nil : shorthand)
		oid = OID(git_reference_target(pointer).pointee)
	}
}

/// A git branch.
public struct Branch: ReferenceType, Hashable {
	/// The full name of the reference (e.g., `refs/heads/master`).
	public let longName: String

	/// The short human-readable name of the branch (e.g., `master`).
	public let name: String

	/// A pointer to the referenced commit.
	public let commit: PointerTo<Commit>

	// MARK: Derived Properties

	/// The short human-readable name of the branch (e.g., `master`).
	///
	/// This is the same as `name`, but is declared with an Optional type to adhere to
	/// `ReferenceType`.
	public var shortName: String? { return name }

	/// The OID of the referenced object.
	///
	/// This is the same as `commit.oid`, but is declared here to adhere to `ReferenceType`.
	public var oid: OID { return commit.oid }

	/// Whether the branch is a local branch.
	public var isLocal: Bool { return longName.hasPrefix("refs/heads/") }

	/// Whether the branch is a remote branch.
	public var isRemote: Bool { return longName.hasPrefix("refs/remotes/") }

	/// Create an instance with a libgit2 `git_reference` object.
	///
	/// Returns `nil` if the pointer isn't a branch.
	public init?(_ pointer: OpaquePointer) {
		var namePointer: UnsafePointer<Int8>? = nil
		let success = git_branch_name(&namePointer, pointer)
		guard success == GIT_OK.rawValue else {
			return nil
		}
		name = String(validatingUTF8: namePointer!)!

		longName = String(validatingUTF8: git_reference_name(pointer))!

		var oid: OID
		if git_reference_type(pointer).rawValue == GIT_REFERENCE_SYMBOLIC.rawValue {
			var resolved: OpaquePointer? = nil
			let success = git_reference_resolve(&resolved, pointer)
			guard success == GIT_OK.rawValue else {
				return nil
			}
			oid = OID(git_reference_target(resolved).pointee)
			git_reference_free(resolved)
		} else {
			oid = OID(git_reference_target(pointer).pointee)
		}
		commit = PointerTo<Commit>(oid)
	}
}

/// A git tag reference, which can be either a lightweight tag or a Tag object.
public enum TagReference: ReferenceType, Hashable {
	/// A lightweight tag, which is just a name and an OID.
	case lightweight(String, OID)

	/// An annotated tag, which points to a Tag object.
	case annotated(String, Tag)

	/// The full name of the reference (e.g., `refs/tags/my-tag`).
	public var longName: String {
		switch self {
		case let .lightweight(name, _):
			return name
		case let .annotated(name, _):
			return name
		}
	}

	/// The short human-readable name of the branch (e.g., `master`).
	public var name: String {
		return String(longName["refs/tags/".endIndex...])
	}

	/// The OID of the target object.
	///
	/// If this is an annotated tag, the OID will be the tag's target.
	public var oid: OID {
		switch self {
		case let .lightweight(_, oid):
			return oid
		case let .annotated(_, tag):
			return tag.target.oid
		}
	}

	// MARK: Derived Properties

	/// The short human-readable name of the branch (e.g., `master`).
	///
	/// This is the same as `name`, but is declared with an Optional type to adhere to
	/// `ReferenceType`.
	public var shortName: String? { return name }

	/// Create an instance with a libgit2 `git_reference` object.
	///
	/// Returns `nil` if the pointer isn't a branch.
	public init?(_ pointer: OpaquePointer) {
		if git_reference_is_tag(pointer) == 0 {
			return nil
		}

		let name = String(validatingUTF8: git_reference_name(pointer))!
		let repo = git_reference_owner(pointer)
		var oid = git_reference_target(pointer).pointee

		var pointer: OpaquePointer? = nil
		let result = git_object_lookup(&pointer, repo, &oid, GIT_OBJECT_TAG)
		if result == GIT_OK.rawValue {
			self = .annotated(name, Tag(pointer!))
		} else {
			self = .lightweight(name, OID(oid))
		}
		git_object_free(pointer)
	}
}
