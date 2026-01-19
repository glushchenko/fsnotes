//
//  SceneDelegate.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.11.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var launchedShortcutItem: UIApplicationShortcutItem?

    var listController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "listViewController") as! ViewController
    var editorController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "editorViewController") as! EditorViewController
    var mainController: MainNavigationController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Handle shortcut from cold launch
        if let shortcutItem = connectionOptions.shortcutItem {
            launchedShortcutItem = shortcutItem
        }

        window = UIWindow(windowScene: windowScene)

        let nav = MainNavigationController(rootViewController: listController)
        nav.setNavigationBarHidden(false, animated: false)
        mainController = nav

        window?.rootViewController = nav
        window?.makeKeyAndVisible()

        editorController.loadViewIfNeeded()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let shortcutItem = self.launchedShortcutItem {
                self.handle(shortcutItem: shortcutItem)
            }

            if let urlContext = connectionOptions.urlContexts.first {
                self.handle(url: urlContext.url)
            }

            if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
                self.configure(window: self.window, with: userActivity)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        saveEditorState()
    }

    // MARK: - Shortcut Actions

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handle(shortcutItem: shortcutItem)
        completionHandler(true)
    }

    private func handle(shortcutItem: UIApplicationShortcutItem) {
        if ShortcutIdentifier(fullType: shortcutItem.type) == .search {
            UIApplication.getVC().enableSearchFocus()
        }

        UIApplication.getVC().handleShortCutItem(shortcutItem)
    }

    // MARK: - URL Handling

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handle(url: url)
    }

    private func handle(url: URL) {
        let vc = UIApplication.getVC()
        let storage = Storage.shared()
        var note = storage.getBy(url: url)

        if url.host == "open" {
            if let tag = url["tag"]?.removingPercentEncoding {
                vc.sidebarTableView.select(tag: tag)
                mainController?.popToRootViewController(animated: true)
                return
            }
        }

        if url.host == "find" {
            if let id = url["id"]?.removingPercentEncoding {
                note = storage.getBy(title: id)
                if !vc.isLoadedDB, note == nil {
                    vc.restoreFindID = id
                    return
                }
            }
        }

        if let note = note {
            UIApplication.getEVC().fill(note: note)
            UIApplication.getVC().openEditorViewController()

            print("File imported: \(note.url)")
        } else {
            guard url.startAccessingSecurityScopedResource(), let inbox = storage.getDefault() else {
                return
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
    }

    // MARK: - State Restoration

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        configure(window: window, with: userActivity)
    }

    func configure(window: UIWindow?, with activity: NSUserActivity) {
        UIApplication.getEVC().restoreUserActivityState(activity)
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }

    // MARK: - Helper Methods

    private func saveEditorState() {
        let evc = UIApplication.getEVC()
        guard evc.navigationController?.topViewController === evc else { return }

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
}
