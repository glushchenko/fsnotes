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

        self.navigationItem.rightBarButtonItems = [getMoreButton(), getEditButton()]

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

        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            navigationController?.navigationBar.standardAppearance = appearance

            updateNavigationBarBackground()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarBackground), name: NSNotification.Name(rawValue: NightNightThemeChangeNotification), object: nil)
    }

    public func getEditButton() -> UIBarButtonItem {
        let menuBtn = SmallButton(type: .custom)
        menuBtn.frame = CGRect(x: 0.0, y: 0.0, width: 18, height: 18)

        let image = UIImage(named: "editMode")!.imageWithColor(color1: .white).resize(maxWidthHeight: 18)

        menuBtn.setImage(image, for: .normal)
        menuBtn.addTarget(self, action: #selector(editMode), for: UIControl.Event.touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: menuBtn)
        let currWidth = menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 18)
        currWidth?.isActive = true
        let currHeight = menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 18)
        currHeight?.isActive = true

        menuBarItem.tintColor = UIColor.white
        return menuBarItem
    }

    @IBAction func editMode() {
        let evc = UIApplication.getEVC()

        if let note = evc.note {
            UserDefaultsManagement.previewMode = false

            evc.fill(note: note)
        }

        UIApplication.getMain()?.scrollInEditorVC()

        if evc.editArea != nil {
            evc.editArea.keyboardAppearance = NightNight.theme == .night ? .dark : .default
            evc.editArea.becomeFirstResponder()
        }

        UserDefaultsManagement.previewMode = false

        // Handoff needs update in cursor position cahnged
        evc.userActivity?.needsSave = true
    }

    @objc public func returnBack() {
        UIApplication.getMain()?.scrollInListVC()

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
        let evc = UIApplication.getEVC()
        guard let note = evc.note else { return }

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

    public func getMoreButton() -> UIBarButtonItem {
        let menuBtn = UIButton(type: .custom)
        menuBtn.frame = CGRect(x: 0.0, y: 0.0, width: 32, height: 32)
        let image = UIImage(named: "more_row_action")!.resize(maxWidthHeight: 32)?.imageWithColor(color1: .white)

        menuBtn.setImage(image, for: .normal)
        menuBtn.addTarget(self, action: #selector(clickOnButton), for: UIControl.Event.touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: menuBtn)
        let currWidth = menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 32)
        currWidth?.isActive = true
        let currHeight = menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 32)
        currHeight?.isActive = true

        menuBarItem.tintColor = UIColor.white
        return menuBarItem
    }

    @objc func clickOnButton() {
        let vc = UIApplication.getVC()
        let pvc = UIApplication.getPVC()
        let evc = UIApplication.getEVC()

        guard let note = evc.note else { return }

        vc.notesTable.actionsSheet(notes: [note], showAll: true, presentController: pvc, back: true)
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

    @objc func updateNavigationBarBackground() {
        if #available(iOS 13.0, *) {
            var color = UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00)

            if NightNight.theme == .night {
                color = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            }

            guard let navController = navigationController else { return }

            navController.navigationBar.standardAppearance.backgroundColor = color
            navController.navigationBar.standardAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            navController.navigationBar.scrollEdgeAppearance = navController.navigationBar.standardAppearance
        }
    }
}
