//
//  StaticSshKeyDelegate.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 14.10.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

class StaticSshKeyDelegate : SshKeyDelegate {
    let privateUrl: URL
    let passphrase: String
    
    init(privateUrl: URL, passphrase: String) {
        self.privateUrl = privateUrl
        self.passphrase = passphrase
    }
    
    public func get(username: String?, url: URL?) -> SshKeyData {
        return RawSshKeyData(username: username, privateKey: privateUrl, passphrase: passphrase)
    }
}
