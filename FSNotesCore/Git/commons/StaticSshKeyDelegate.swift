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
    let publicUrl: URL?
    let passphrase: String
    
    init(privateUrl: URL, passphrase: String, publicUrl: URL? = nil) {
        self.privateUrl = privateUrl
        self.publicUrl = publicUrl
        self.passphrase = passphrase
    }
    
    public func get(username: String?, url: URL?) -> SshKeyData {
        if let publicUrl = self.publicUrl {
            return RawSshKeyData(username: username, privateKey: privateUrl, publicKey: publicUrl, passphrase: passphrase)
        }

        return RawSshKeyData(username: username, privateKey: privateUrl, publicKey: nil, passphrase: passphrase)
    }
}
