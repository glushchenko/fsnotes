//
//  AppDelegate.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import CoreData
import NightNight
import FSNotesCore_iOS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    public var window: UIWindow?
    public var launchedShortcutItem: UIApplicationShortcutItem?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        var shouldPerformAdditionalDelegateHandling = true

        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            launchedShortcutItem = shortcutItem
            shouldPerformAdditionalDelegateHandling = false
        }
        
        let newDocument = NSLocalizedString("New document", comment: "")
        let shortcutNew = UIMutableApplicationShortcutItem(
            type: ShortcutIdentifier.makeNew.type,
            localizedTitle: newDocument,
            localizedSubtitle: "",
            icon: UIApplicationShortcutIcon(type: .compose),
            userInfo: nil
        )

        let saveClipboard = NSLocalizedString("Save clipboard", comment: "")
        let shortcutNewClipboard = UIMutableApplicationShortcutItem(
            type: ShortcutIdentifier.clipboard.type,
            localizedTitle: saveClipboard,
            localizedSubtitle: "",
            icon: UIApplicationShortcutIcon(type: .add),
            userInfo: nil
        )

        let search = NSLocalizedString("Search", comment: "")
        let focus = NSLocalizedString("Focus in search field", comment: "")
        let shortcutSearch = UIMutableApplicationShortcutItem(
            type: ShortcutIdentifier.search.type,
            localizedTitle: search,
            localizedSubtitle: focus,
            icon: UIApplicationShortcutIcon(type: .search),
            userInfo: nil
        )

        application.shortcutItems = [shortcutNew, shortcutNewClipboard, shortcutSearch]
        
        return shouldPerformAdditionalDelegateHandling
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.


        UIApplication.getEVC().saveContentOffset()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        let temp = NSTemporaryDirectory()

        let encryption = URL(fileURLWithPath: temp).appendingPathComponent("Encryption")
        try? FileManager.default.removeItem(at: encryption)

        let webkitPreview = URL(fileURLWithPath: temp).appendingPathComponent("wkPreview")
        try? FileManager.default.removeItem(at: webkitPreview)

        Storage.shared().saveProjectsCache()
        UserDefaultsManagement.crashedLastTime = false

        print("Termination end, crash status: \(UserDefaultsManagement.crashedLastTime)")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {        
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        guard let shortcut = launchedShortcutItem else { return }
        _ = handleShortCutItem(shortcut)
        
        // Reset which shortcut was chosen for next time.
        launchedShortcutItem = nil
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UIApplication.shared.statusBarStyle = .lightContent
        
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").standardized {

            if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                do {
                    try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Home directory creation: \(error)")
                }
            }
        }
                
        return true
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handledShortCutItem = handleShortCutItem(shortcutItem)
        completionHandler(handledShortCutItem)
    }

    // MARK: Static Properties
    static let applicationShortcutUserInfoIconKey = "applicationShortcutUserInfoIconKey"
    
    func handleShortCutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        var handled = false
        guard ShortcutIdentifier(fullType: shortcutItem.type) != nil else { return false }
        guard let shortCutType = shortcutItem.type as String? else { return false }

        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController
        else { return false }
        
        switch shortCutType {
        case ShortcutIdentifier.makeNew.type:
            vc.createNote()

            handled = true
            break
        case ShortcutIdentifier.clipboard.type:
            vc.createNote(pasteboard: true)

            handled = true
            break
        case ShortcutIdentifier.search.type:
            pc.containerController.selectController(atIndex: 0, animated: true)
            vc.searchView.isHidden = false
            vc.search.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0.5)
            handled = true
            break
        default:
            
            break
        }

        return handled
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

        if url.host == "open" {
            if let tag = url["tag"]?.removingPercentEncoding {
                UIApplication.getVC().sidebarTableView.select(tag: tag)
            }
        }

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        UIApplication.getEVC().restoreUserActivityState(userActivity)

        return true
    }

    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return true
    }
}

