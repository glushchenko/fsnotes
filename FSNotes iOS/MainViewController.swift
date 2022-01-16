//
//  MainViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 14.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class MainViewController: SwipeViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        scrollDidMoveToControllerIndex() { controllerIndex in
            switch controllerIndex {
            case 0:
                UIApplication.getEVC().userActivity?.invalidate()
                UIApplication.getPVC().clear()

                self.disableSwipe()
                break
            case 1:
                self.enableSwipe()
                UserDefaultsManagement.previewMode = false
                break
            case 2:
                self.enableSwipe()
                break
            default: break
            }
        }
    }

    public func scrollInListVC() {
        scrollToNextViewController(0)
    }

    public func scrollInEditorVC() {
        scrollToNextViewController(1)
    }

    public func scrollInPreviewVC() {
        scrollToNextViewController(2)
    }

    public func disableSwipe() {
        guard let scrollView = pageController.view.subviews.compactMap({ $0 as? UIScrollView }).first else { return }

        scrollView.isScrollEnabled = false
    }

    public func enableSwipe() {
        guard let scrollView = pageController.view.subviews.compactMap({ $0 as? UIScrollView }).first else { return }

        scrollView.isScrollEnabled = true
    }

    public func restoreLastController() {
        guard !Storage.shared().isCrashedLastTime else { return }

        DispatchQueue.main.async {
            if let noteURL = UserDefaultsManagement.currentNote,
               let controller = UserDefaultsManagement.currentController,
               controller != 0
            {
                if FileManager.default.fileExists(atPath: noteURL.path),
                   let project = Storage.shared().getProjectByNote(url: noteURL)
                {
                    let note = Note(url: noteURL, with: project)

                    if !note.isEncrypted()  {
                        self.scrollToNextViewController(controller)

                        let evc = UIApplication.getEVC()
                        evc.fill(note: note)

                        if UserDefaultsManagement.currentEditorState == true,
                           let selectedRange = UserDefaultsManagement.currentRange
                        {
                            if selectedRange.upperBound <= note.content.length {
                                evc.editArea.selectedRange = selectedRange
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                evc.editArea.becomeFirstResponder()
                            }
                        }
                    }
                }
            }
        }
    }
}
