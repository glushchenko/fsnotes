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

    public var window: UIWindow?
    public var launchedShortcutItem: UIApplicationShortcutItem?
    public var listController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "listViewController") as! ViewController
    public var editorController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "editorViewController") as! EditorViewController

    public var mainController: MainNavigationController?

    public static var gitVC = [String: GitViewController]()
    public static var gitProgress: GitProgress?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        var shouldPerformAdditionalDelegateHandling = true

        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            launchedShortcutItem = shortcutItem
            shouldPerformAdditionalDelegateHandling = false
        }
        
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

        let nav = MainNavigationController(rootViewController: listController)
        nav.setNavigationBarHidden(false, animated: false)

        mainController = nav
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()

        // Controller outlets loading
        editorController.loadViewIfNeeded()

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

    func applicationWillTerminate(_ application: UIApplication) {
        UserDefaultsManagement.crashedLastTime = false
        
        saveEditorState()
        
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

        let vc = UIApplication.getVC()

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
            vc.loadViewIfNeeded()
            vc.popViewController()
            vc.loadSearchController()
            handled = true
            break
        default:
            
            break
        }

        return handled
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let vc = UIApplication.getVC()
        let storage = Storage.shared()
        var note = storage.getBy(url: url)

        if url.host == "open" {
            if let tag = url["tag"]?.removingPercentEncoding {
                vc.sidebarTableView.select(tag: tag)
                mainController?.popToRootViewController(animated: true)
                return true
            }
        }
        
        if url.host == "find" {
            if let id = url["id"]?.removingPercentEncoding {
                note = storage.getBy(title: id)
                if !vc.isLoadedDB, note == nil {
                    vc.restoreFindID = id
                }
            }
        }

        if let note = note {
            UIApplication.getEVC().fill(note: note)
            UIApplication.getVC().openEditorViewController()

            print("File imported: \(note.url)")
        } else {
            
            guard url.startAccessingSecurityScopedResource(), let inbox = storage.getDefault() else {
                return false
            }

            let dst = NameHelper.getUniqueFileName(name: "", project: inbox, ext: url.pathExtension)

            do {
                try FileManager.default.copyItem(at: url, to: dst)

                if let note = storage.importNote(url: dst) {
                    vc.notesTable.insertRows(notes: [note])
                    vc.updateNotesCounter()
                }
            } catch {
                print("Note opening error: \(error)")
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

    private func saveEditorState() {
        let evc = UIApplication.getEVC()
        guard evc.navigationController?.topViewController === evc else {return }

        if let url = evc.note?.url {
            UserDefaultsManagement.currentEditorState = evc.editArea.isFirstResponder

            if evc.note?.previewState == true {
                UserDefaultsManagement.currentRange = nil
            } else {
                UserDefaultsManagement.currentRange = evc.editArea.selectedRange
            }

            UserDefaultsManagement.currentNote = url
        }
    }

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

