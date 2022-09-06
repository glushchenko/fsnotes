//
//  Credentials.swift
//  SwiftGit2
//
//  Created by Tom Booth on 29/02/2016.
//  Copyright © 2016 GitHub, Inc. All rights reserved.
//

import Cgit2

private class Wrapper<T> {
	let value: T

	init(_ value: T) {
		self.value = value
	}
}

public enum Credentials {
	case `default`
	case sshAgent
	case plaintext(username: String, password: String)
	case sshMemory(username: String, privateKey: String, passphrase: String)

	private static var previouslyUsedPointer: String? = nil
    private static var previouslyUsedCredentials: Credentials? = nil
	internal static func fromPointer(_ pointer: UnsafeMutableRawPointer) -> Credentials {
		// check if we had just seen this pointer
		if pointer.debugDescription == previouslyUsedPointer {
			// we have already used this pointer, so it is likely that libgit2
			// has already freed the memory and using Unmanaged<>.fromOpaque will
			// result in a BAD_ACCESS crash
            return previouslyUsedCredentials!
		} else {
			// mark that we have used this pointer so that
			// later attempts to use it in this function will
			// be blocked
			previouslyUsedPointer = pointer.debugDescription
            previouslyUsedCredentials = Unmanaged<Wrapper<Credentials>>.fromOpaque(UnsafeRawPointer(pointer)).takeRetainedValue().value
			// access the pointer and convert it into a
			// Credentials Swift object
			return previouslyUsedCredentials!
		}
	}

	internal func toPointer() -> UnsafeMutableRawPointer {
		return Unmanaged.passRetained(Wrapper(self)).toOpaque()
	}
}

/// Handle the request of credentials, passing through to a wrapped block after converting the arguments.
/// Converts the result to the correct error code required by libgit2 (0 = success, 1 = rejected setting creds,
/// -1 = error)
internal func credentialsCallback(
	cred: UnsafeMutablePointer<UnsafeMutablePointer<git_cred>?>?,
	url: UnsafePointer<CChar>?,
	username: UnsafePointer<CChar>?,
	_: UInt32,
	payload: UnsafeMutableRawPointer? ) -> Int32 {

	let result: Int32

	// Find username_from_url
	let name = username.map(String.init(cString:))

//    guard  else {
//        return 1
//    }
    let credential = Credentials.fromPointer(payload!)
    
	switch credential {
	case .default:
		result = git_cred_default_new(cred)
	case .sshAgent:
		result = git_cred_ssh_key_from_agent(cred, name!)
	case .plaintext(let username, let password):
		result = git_cred_userpass_plaintext_new(cred, username, password)
	case .sshMemory(let username, let privateKey, let passphrase):
		result = git_cred_ssh_key_memory_new(cred, username, nil, privateKey, passphrase)
	}

	return (result != GIT_OK.rawValue) ? -1 : 0
}
