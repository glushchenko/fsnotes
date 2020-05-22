//
//  PreviewViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/5/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class PreviewViewController: UIViewController {
    private var isLandscape: Bool?

    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = Colors.buttonText
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.navigationBar.mixedBackgroundColor = Colors.Header

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(returnBack))

        self.navigationItem.rightBarButtonItem = getShareButton()

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)

        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    public func getShareButton() -> UIBarButtonItem {
        let menuBtn = UIButton(type: .custom)
        menuBtn.frame = CGRect(x: 0.0, y: 0.0, width: 20, height: 20)
        menuBtn.setImage(UIImage(named: "share"), for: .normal)
        menuBtn.addTarget(self, action: #selector(share), for: UIControl.Event.touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: menuBtn)
        let currWidth = menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 24)
        currWidth?.isActive = true
        let currHeight = menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 24)
        currHeight?.isActive = true

        menuBarItem.tintColor = UIColor.white
        return menuBarItem
    }

    @IBAction func share() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let navPC = bvc.containerController.viewControllers[2] as? UINavigationController,
            let vc = bvc.containerController.viewControllers[0] as? ViewController,
            let pvc = navPC.viewControllers.first as? PreviewViewController,
            let navEC = bvc.containerController.viewControllers[1] as? UINavigationController,
            let evc = navEC.viewControllers.first as? EditorViewController,
            let note = evc.note
        else { return }

        vc.notesTable.shareAction(note: note, presentController: pvc, isHTML: true)
    }

    @objc public func returnBack() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else { return }
        clear()
        bvc.containerController.selectController(atIndex: 0, animated: true)
    }

    @objc func rotated() {
        guard isLandscape != nil else {
            isLandscape = UIDevice.current.orientation.isLandscape
            return
        }

        if let landscape = self.isLandscape, landscape != UIDevice.current.orientation.isLandscape, !UIDevice.current.orientation.isFlat {
            isLandscape = UIDevice.current.orientation.isLandscape
            reloadPreview()
        }
    }

    public func loadPreview() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let nav = bvc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController,
            let note = evc.note
        else { return }

        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)

        let markdownString = note.content.unLoadImages().string
        do {
            var imagesStorage = note.project.url

            if note.isTextBundle() {
                imagesStorage = note.getURL()
            }

            for sub in self.view.subviews {
                if sub.isKind(of: MarkdownView.self) {
                    sub.removeFromSuperview()
                }
            }

            if let downView = try? MarkdownView(imagesStorage: imagesStorage, frame: self.view.frame, markdownString: markdownString, css: "", templateBundle: bundle) {
                downView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(downView)
            }
        }
        return
    }

    @objc func clickOnButton() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = bvc.containerController.viewControllers[0] as? ViewController,
            let nav = bvc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController,
            let note = evc.note,
            let navPVC = bvc.containerController.viewControllers[2] as? UINavigationController,
            let pvc = navPVC.viewControllers.first as? PreviewViewController
        else { return }

        vc.notesTable.actionsSheet(notes: [note], showAll: true, presentController: navPVC)
    }

    public func reloadPreview() {
        DispatchQueue.main.async {
            for sub in self.view.subviews {
                if sub.isKind(of: MarkdownView.self) {
                    sub.removeFromSuperview()
                }
            }

            self.loadPreview()
        }
    }

    public func setTitle(text: String) {
        let button =  UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        button.setTitle(text, for: .normal)
        button.addTarget(self, action: #selector(clickOnButton), for: .touchUpInside)
        navigationItem.titleView = button
        navigationItem.title = text
    }

    public func clear() {
        for sub in self.view.subviews {
            if sub.isKind(of: MarkdownView.self) {
                sub.removeFromSuperview()
            }
        }
    }
}
