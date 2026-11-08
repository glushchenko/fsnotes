//
//  SceneDelegate.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.11.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit
import WidgetKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private static var inboxNoteRequested = false
    private(set) var isOpeningInboxFromWidget = false

    static func requestInboxNote() {
        inboxNoteRequested = true
        UIApplication.getSceneDelegate()?.openRequestedInboxNote()
    }

    func openRequestedInboxNote() {
        guard Self.inboxNoteRequested,
              window?.windowScene?.activationState == .foregroundActive,
              listController.isLoadedDB else {
            return
        }

        Self.inboxNoteRequested = false
        listController.openNewInboxNote()
    }

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
        let launchURL = connectionOptions.urlContexts.first?.url
        let opensInbox = launchURL == InboxWidgetSnapshot.inboxURL
        isOpeningInboxFromWidget = opensInbox

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

            if opensInbox {
                self.openRequestedInboxFromWidget()
                return
            }

            if let launchURL {
                self.handle(url: launchURL)
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
        openRequestedInboxNote()
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
        refreshInboxWidget()
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
        if url == InboxWidgetSnapshot.inboxURL {
            isOpeningInboxFromWidget = true
            openRequestedInboxFromWidget()
            return
        }

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
            guard let inbox = storage.getDefault(), url.startAccessingSecurityScopedResource() else {
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

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

    func openRequestedInboxFromWidget() {
        guard isOpeningInboxFromWidget, listController.isLoadedDB else { return }

        isOpeningInboxFromWidget = false
        listController.openInboxFromWidget()
    }

    func refreshInboxWidget() {
        guard listController.isLoadedDB else { return }

        let notes = listController.storage.noteList.filter { !$0.isTrash() && !$0.name.isEmpty }
        let inbox = notes.filter { $0.project.isDefault }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thresholds = inbox.compactMap { note -> Date? in
            let added = (try? note.url.resourceValues(forKeys: [.addedToDirectoryDateKey]))?.addedToDirectoryDate
            guard let date = added ?? note.creationDate, date != .distantPast else { return nil }
            let inboxDay = min(calendar.startOfDay(for: date), today)
            return calendar.date(byAdding: .day, value: 7, to: inboxDay)
        }

        let snapshot = InboxWidgetSnapshot(
            inboxCount: inbox.count,
            totalCount: notes.count,
            weekThresholds: thresholds.sorted()
        )

        do {
            if try snapshot.write() {
                WidgetCenter.shared.reloadTimelines(ofKind: InboxWidgetSnapshot.kind)
            }
        } catch {
            print("Inbox widget snapshot could not be updated: \(error.localizedDescription)")
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
