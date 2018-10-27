//
//  AppDelegate.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import CoreData
import Solar
import NightNight
import CoreLocation

import FSNotesCore_iOS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var launchedShortcutItem: UIApplicationShortcutItem?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        var shouldPerformAdditionalDelegateHandling = true
        
        if let shortcutItem = launchOptions?[UIApplicationLaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            launchedShortcutItem = shortcutItem
            shouldPerformAdditionalDelegateHandling = false
        }
        
        if let shortcutItems = application.shortcutItems, shortcutItems.isEmpty {
            let shortcutNew = UIMutableApplicationShortcutItem(type: ShortcutIdentifier.makeNew.type,
                                                             localizedTitle: "New document",
                                                             localizedSubtitle: "",
                                                             icon: UIApplicationShortcutIcon(type: .compose),
                                                             userInfo: nil)
            
            let shortcutNewClipboard = UIMutableApplicationShortcutItem(type: ShortcutIdentifier.clipboard.type,
                                                               localizedTitle: "Save clipboard",
                                                               localizedSubtitle: "",
                                                               icon: UIApplicationShortcutIcon(type: .add),
                                                               userInfo: nil)
            
            let shortcutSearch = UIMutableApplicationShortcutItem(type: ShortcutIdentifier.search.type,
                                                             localizedTitle: "Search",
                                                             localizedSubtitle: "Focus in search field",
                                                             icon: UIApplicationShortcutIcon(type: .search),
                                                             userInfo: nil)
            
            application.shortcutItems = [shortcutNew, shortcutNewClipboard, shortcutSearch]
        }
        
        return shouldPerformAdditionalDelegateHandling
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        let locationManager = CLLocationManager()
        if UserDefaultsManagement.nightModeAuto,
            let location = locationManager.location,
            let solar = Solar.init(coordinate: location.coordinate) {

            NightNight.theme = solar.isNighttime ? .night : .normal

            guard
                let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
                let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
                let evc = viewController.viewControllers[0] as? EditorViewController,
                let vc = pageController.orderedViewControllers[0] as? ViewController else {
                    return
            }

            evc.refill()
            vc.sidebarTableView.sidebar = Sidebar()
            vc.sidebarTableView.reloadData()
            vc.notesTable.reloadData()
        }
        
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        guard let shortcut = launchedShortcutItem else { return }
        _ = handleShortCutItem(shortcut)
        
        // Reset which shortcut was chosen for next time.
        launchedShortcutItem = nil
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {

        UIApplication.shared.statusBarStyle = .lightContent
        
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {

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
        guard let pageViewController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageViewController.orderedViewControllers[0] as? ViewController else {
            return false
        }
        
        switch shortCutType {
        case ShortcutIdentifier.makeNew.type:
            viewController.is3DTouchShortcut = true
            viewController.createNote()
            handled = true
            break
        case ShortcutIdentifier.clipboard.type:
            guard let navigationViewController = pageViewController.orderedViewControllers[1] as? UINavigationController, let evc = navigationViewController.viewControllers[0] as? EditorViewController
            else { return false }
                    
            viewController.is3DTouchShortcut = true
            viewController.createNote(pasteboard: true)
            evc.editArea.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0.1)

            handled = true
            break
        case ShortcutIdentifier.search.type:
            pageViewController.switchToList()
            viewController.searchView.isHidden = false
            viewController.search.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0.5)
            handled = true
            break
        default:
            
            break
        }

        return handled
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }
    
    
}

