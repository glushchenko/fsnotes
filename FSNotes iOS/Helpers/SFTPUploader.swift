//
//  SFTPUploader.swift
//  FSNotes iOS
//
//  SFTP web publishing for iOS, mirroring the macOS ViewController+Web.swift logic.
//  Private keys are stored as raw Data in UserDefaultsManagement.sftpAccessData and
//  written to a temporary file for libssh2, then immediately deleted after use.
//

import Foundation
import Shout

/// Wraps any error so its description is always visible via `localizedDescription`,
/// even for types (like Shout's SSHError) that don't conform to LocalizedError.
private struct DescriptiveError: LocalizedError {
    let errorDescription: String?
    init(_ error: Error) {
        if let le = error as? LocalizedError, let msg = le.errorDescription, !msg.isEmpty {
            errorDescription = msg
        } else {
            errorDescription = String(describing: error)
        }
    }
}

enum SFTPUploaderError: LocalizedError {
    case missingCredentials
    case missingPath
    case missingWebURL
    case buildPageFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return NSLocalizedString("Please set a password or import a private key in SFTP settings.", comment: "")
        case .missingPath:        return NSLocalizedString("Remote path is not configured in SFTP settings.", comment: "")
        case .missingWebURL:      return NSLocalizedString("Web URL is not configured in SFTP settings.", comment: "")
        case .buildPageFailed:    return NSLocalizedString("Failed to render the note as HTML.", comment: "")
        }
    }
}

struct SFTPUploader {

    // MARK: - Public API

    /// Uploads a note to the configured SFTP server and returns the public web URL.
    static func upload(note: Note, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global().async {
            do {
                guard let sftpPath = UserDefaultsManagement.sftpPath, !sftpPath.isEmpty else {
                    throw SFTPUploaderError.missingPath
                }
                guard let webBase = UserDefaultsManagement.sftpWeb, !webBase.isEmpty else {
                    throw SFTPUploaderError.missingWebURL
                }

                let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SFTPUpload")
                try? FileManager.default.removeItem(at: dst)

                guard let localURL = MPreviewView.buildPage(for: note, at: dst, web: true) else {
                    throw SFTPUploaderError.buildPageFailed
                }

                let latinName = note.getLatinName()
                let remoteDir = sftpPath.hasSuffix("/") ? "\(sftpPath)\(latinName)/" : "\(sftpPath)/\(latinName)/"
                let resultURL = URL(string: webBase.hasSuffix("/") ? webBase + latinName + "/" : webBase + "/" + latinName + "/")!
                let images = note.content.getImagesAndFiles()

                guard let ssh = try makeSSH() else {
                    throw SFTPUploaderError.missingCredentials
                }

                try ssh.execute("mkdir -p \(remoteDir)")

                let sftp = try ssh.openSftp()

                // Upload index.html
                let remoteIndex = remoteDir + "index.html"
                _ = try? ssh.execute("rm -f \(remoteIndex)")
                try sftp.upload(localURL: localURL, remotePath: remoteIndex)

                // Upload zip archive if present
                let zipURL = localURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(latinName)
                    .appendingPathExtension("zip")
                if FileManager.default.fileExists(atPath: zipURL.path) {
                    try? sftp.upload(localURL: zipURL, remotePath: remoteDir + latinName + ".zip")
                }

                // Upload images
                var imageDirCreated = false
                for image in images {
                    if image.path.hasPrefix("http://") || image.path.hasPrefix("https://") {
                        continue
                    }
                    if !imageDirCreated {
                        try ssh.execute("mkdir -p \(remoteDir)i/")
                        imageDirCreated = true
                    }
                    try? sftp.upload(localURL: image.url, remotePath: remoteDir + "i/" + image.url.lastPathComponent)
                }

                note.uploadPath = remoteDir
                Storage.shared().saveUploadPaths()

                DispatchQueue.main.async {
                    completion(.success(resultURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(DescriptiveError(error)))
                }
            }
        }
    }

    /// Removes a previously uploaded note from the SFTP server.
    static func remove(note: Note, completion: @escaping (Error?) -> Void) {
        guard let remotePath = note.uploadPath else {
            completion(nil)
            return
        }

        DispatchQueue.global().async {
            do {
                guard let ssh = try makeSSH() else {
                    throw SFTPUploaderError.missingCredentials
                }

                try ssh.execute("rm -rf \(remotePath)")

                note.uploadPath = nil
                Storage.shared().saveUploadPaths()

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(DescriptiveError(error))
                }
            }
        }
    }

    // MARK: - SSH session factory

    /// Creates and authenticates an SSH session using the configured credentials.
    /// Returns nil (without throwing) when credentials are simply absent/incomplete,
    /// throws when a connection or auth error occurs.
    static func makeSSH() throws -> SSH? {
        let host = UserDefaultsManagement.sftpHost
        let port = UserDefaultsManagement.sftpPort
        let username = UserDefaultsManagement.sftpUsername
        let password = UserDefaultsManagement.sftpPassword
        let passphrase = UserDefaultsManagement.sftpPassphrase

        guard !host.isEmpty else { return nil }

        let ssh = try SSH(host: host, port: port > 0 ? port : 22)

        if !password.isEmpty {
            try ssh.authenticate(username: username, password: password)
            return ssh
        }

        // Key-based auth: write key data to temp files, authenticate, then delete
        if let keyData = UserDefaultsManagement.sftpAccessData {
            let rand = Int.random(in: 1000...9999)
            let tmpKey = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("fsnotes_sftp_key_\(rand)")
            try keyData.write(to: tmpKey)
            defer { try? FileManager.default.removeItem(at: tmpKey) }

            var tmpPubKeyPath: String? = nil
            var tmpPubKey: URL? = nil
            if let pubKeyData = UserDefaultsManagement.sftpPublicKeyData {
                let tmpPub = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("fsnotes_sftp_key_\(rand).pub")
                try pubKeyData.write(to: tmpPub)
                tmpPubKey = tmpPub
                tmpPubKeyPath = tmpPub.path
            }
            defer { if let u = tmpPubKey { try? FileManager.default.removeItem(at: u) } }

            let passValue = passphrase.isEmpty ? nil : passphrase
            try ssh.authenticate(username: username, privateKey: tmpKey.path, publicKey: tmpPubKeyPath, passphrase: passValue)
            return ssh
        }

        return nil
    }
}
