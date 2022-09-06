//
// Created by Arnon Keereena on 4/28/17.
// Copyright (c) 2017 GitHub, Inc. All rights reserved.
//

import Foundation
import Cgit2

public class CommitIterator: IteratorProtocol, Sequence {
	public typealias Iterator = CommitIterator
	public typealias Element = Result<Commit, NSError>
	let repo: Repository
	private var revisionWalker: OpaquePointer?

	private enum Next {
		case over
		case okay
		case error(NSError)

		init(_ result: Int32, name: String) {
			switch result {
			case GIT_ITEROVER.rawValue:
				self = .over
			case GIT_OK.rawValue:
				self = .okay
			default:
				self = .error(NSError(gitError: result, pointOfFailure: name))
			}
		}
	}

	init(repo: Repository, root: git_oid) {
		self.repo = repo
		setupRevisionWalker(root: root)
	}

	deinit {
		git_revwalk_free(self.revisionWalker)
	}

	private func setupRevisionWalker(root: git_oid) {
		var oid = root
		git_revwalk_new(&revisionWalker, repo.pointer)
		git_revwalk_sorting(revisionWalker, GIT_SORT_TOPOLOGICAL.rawValue)
		git_revwalk_sorting(revisionWalker, GIT_SORT_TIME.rawValue)
		git_revwalk_push(revisionWalker, &oid)
	}

	public func next() -> Element? {
		var oid = git_oid()
		let revwalkGitResult = git_revwalk_next(&oid, revisionWalker)
		let nextResult = Next(revwalkGitResult, name: "git_revwalk_next")
		switch nextResult {
		case let .error(error):
			return Result.failure(error)
		case .over:
			return nil
		case .okay:
			var unsafeCommit: OpaquePointer? = nil
			let lookupGitResult = git_commit_lookup(&unsafeCommit, repo.pointer, &oid)
			guard lookupGitResult == GIT_OK.rawValue,
				let unwrapCommit = unsafeCommit else {
					return Result.failure(NSError(gitError: lookupGitResult, pointOfFailure: "git_commit_lookup"))
			}
			let result: Element = Result.success(Commit(unwrapCommit))
			git_commit_free(unsafeCommit)
			return result
		}
	}
}
