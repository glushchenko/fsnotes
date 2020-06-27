//
//  PreviewViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/5/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class PreviewViewController: UIViewController, UIGestureRecognizerDelegate {
    private var isLandscape: Bool?
    private var modifiedAt = Date()

    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = Colors.buttonText
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.navigationBar.mixedBackgroundColor = Colors.Header

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(returnBack))

        self.navigationItem.rightBarButtonItem = getEditButton()

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)

        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIContentSizeCategory.didChangeNotification, object: nil)

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(editMode))
        tapGR.delegate = self
        tapGR.numberOfTapsRequired = 2
        view.addGestureRecognizer(tapGR)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(returnBack))
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        self.view.addGestureRecognizer(swipeRight)
    }

    public func getEditButton() -> UIBarButtonItem {
        let menuBtn = UIButton(type: .custom)
        menuBtn.frame = CGRect(x: 0.0, y: 0.0, width: 20, height: 20)

        let image = UIImage(named: "edit_preview_controller")!.imageWithColor(color1: .white)

        menuBtn.setImage(image, for: .normal)
        menuBtn.addTarget(self, action: #selector(editMode), for: UIControl.Event.touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: menuBtn)
        let currWidth = menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 24)
        currWidth?.isActive = true
        let currHeight = menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 24)
        currHeight?.isActive = true

        menuBarItem.tintColor = UIColor.white
        return menuBarItem
    }

    @IBAction func editMode() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let nav = bvc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController
        else { return }

        if let note = evc.note {
            UserDefaultsManagement.previewMode = false

            UIApplication.getEVC().fill(note: note)
        }

        bvc.containerController.selectController(atIndex: 1, animated: false)

        if evc.editArea != nil {
            evc.editArea.keyboardAppearance = NightNight.theme == .night ? .dark : .default
            evc.editArea.becomeFirstResponder()
        }

        UserDefaultsManagement.previewMode = false

        // Handoff needs update in cursor position cahnged
        UIApplication.getEVC().userActivity?.needsSave = true
    }

    @objc public func returnBack() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else { return }

        guard bvc.containerController.isMoveFinished else { return }

        bvc.containerController.selectController(atIndex: 0, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.clear()
        }
    }

    @objc func rotated() {
        guard isLandscape != nil else {
            isLandscape = UIDevice.current.orientation.isLandscape
            navigationController?.isNavigationBarHidden = isLandscape!
            return
        }

        let isLand = UIDevice.current.orientation.isLandscape
        if let landscape = self.isLandscape, landscape != isLand, !UIDevice.current.orientation.isFlat {
            isLandscape = isLand
            navigationController?.isNavigationBarHidden = isLand

            removeMPreviewView()
            loadPreview(force: true)
        } else {
            navigationController?.isNavigationBarHidden = false
        }
    }

    public func loadPreview(force: Bool = false) {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let nav = bvc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController,
            let note = evc.note
        else { return }

        let isForceRequest = note.modifiedLocalAt != modifiedAt || force
        modifiedAt = note.modifiedLocalAt

        for sub in self.view.subviews {
            if sub.isKind(of: MPreviewView.self) {
                if let view = sub as? MPreviewView {
                    view.load(note: note, force: isForceRequest)
                    return
                }
            }
        }

        let mPreview = MPreviewView(frame: self.view.frame, note: note, closure: {})
        mPreview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mPreview)
        
        mPreview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        mPreview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        mPreview.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        mPreview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
    }

    @objc func clickOnButton() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = bvc.containerController.viewControllers[0] as? ViewController,
            let nav = bvc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController,
            let note = evc.note,
            let navPVC = bvc.containerController.viewControllers[2] as? UINavigationController
        else { return }

        vc.notesTable.actionsSheet(notes: [note], showAll: true, presentController: navPVC)
    }

    public func setTitle(text: String) {
        let button =  UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        button.setTitle(text, for: .normal)
        button.addTarget(self, action: #selector(clickOnButton), for: .touchUpInside)
        navigationItem.titleView = button
        navigationItem.title = text
    }

    public func removeMPreviewView() {
        for sub in self.view.subviews {
            if sub.isKind(of: MPreviewView.self) {
                sub.removeFromSuperview()
            }
        }

        view.removeConstraints(view.constraints)
    }

    public func clear() {
        for sub in self.view.subviews {
            if sub.isKind(of: MPreviewView.self) {
                if let view = sub as? MPreviewView {
                    try? view.loadHTMLView("", css: "")
                }
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard UserDefaultsManagement.nightModeType == .system else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkDarkMode()
        }
    }

    public func checkDarkMode() {
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                if NightNight.theme != .night {
                    UIApplication.getVC().enableNightMode()
                }
            } else {
                if NightNight.theme == .night {
                    UIApplication.getVC().disableNightMode()
                }
            }
        }
    }
}
