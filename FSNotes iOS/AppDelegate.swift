//
//  AppDelegate.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

//
//  AppDelegate.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    public static var gitVC = [String: GitViewController]()
    public static var gitProgress: GitProgress?

    // MARK: Static Properties
    static let applicationShortcutUserInfoIconKey = "applicationShortcutUserInfoIconKey"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Setup dynamic shortcuts
        let newDocument = NSLocalizedString("New Note", comment: "")
        let shortcutNew = UIMutableApplicationShortcutItem(
            type: ShortcutIdentifier.makeNew.type,
            localizedTitle: newDocument,
            localizedSubtitle: "",
            icon: UIApplicationShortcutIcon(type: .compose),
            userInfo: nil
        )

        let saveClipboard = NSLocalizedString("Save Clipboard", comment: "")
        let shortcutNewClipboard = UIMutableApplicationShortcutItem(
            type: ShortcutIdentifier.clipboard.type,
            localizedTitle: saveClipboard,
            localizedSubtitle: "",
            icon: UIApplicationShortcutIcon(type: .add),
            userInfo: nil
        )

        let search = NSLocalizedString("Search or Create", comment: "")
        let shortcutSearch = UIMutableApplicationShortcutItem(
            type: ShortcutIdentifier.search.type,
            localizedTitle: search,
            localizedSubtitle: "",
            icon: UIApplicationShortcutIcon(type: .search),
            userInfo: nil
        )

        application.shortcutItems = [shortcutNew, shortcutNewClipboard, shortcutSearch]

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        UserDefaultsManagement.crashedLastTime = false

        let temp = NSTemporaryDirectory()

        let encryption = URL(fileURLWithPath: temp).appendingPathComponent("Encryption")
        try? FileManager.default.removeItem(at: encryption)

        let webkitPreview = URL(fileURLWithPath: temp).appendingPathComponent("wkPreview")
        try? FileManager.default.removeItem(at: webkitPreview)

        let imagesPreview = URL(fileURLWithPath: temp).appendingPathComponent("ThumbnailsBig")
        try? FileManager.default.removeItem(at: imagesPreview)

        Storage.shared().saveProjectsCache()

        print("Termination end, crash status: \(UserDefaultsManagement.crashedLastTime)")
    }

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").standardized,
           !FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil) {

            do {
                try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Home directory creation: \(error)")
            }
        }

        return true
    }

    // MARK: - Static Helper Methods

    public static func getGitVC(for project: Project) -> GitViewController {
        if let gitVC = AppDelegate.gitVC[project.settingsKey] {
            return gitVC
        }

        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let gvc = storyBoard.instantiateViewController(withIdentifier: "gitSettingsViewController") as! GitViewController
        gvc.setProject(project)

        AppDelegate.gitVC[project.settingsKey] = gvc

        return gvc
    }

    public static func getGitVCOptional(for project: Project) -> GitViewController? {
        if let gitVC = AppDelegate.gitVC[project.settingsKey] {
            return gitVC
        }

        return nil
    }
}
