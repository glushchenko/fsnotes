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
    private var orientation: UIDeviceOrientation?

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
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let mvc = pageController.mainViewController,
            let evc = pageController.editorViewController,
            let note = evc.note
        else { return }

        mvc.notesTable.shareAction(note: note, presentController: evc, isHTML: true)
    }

    @objc public func returnBack() {
        if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController {
            clear()
            pageController.switchToList()
        }
    }

    @objc func rotated() {
        guard orientation != nil else {
            orientation = UIDevice.current.orientation
            return
        }

        if UIDevice.current.orientation != orientation {
            reloadPreview()
        }
    }

    public func loadPreview() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let evc = pageController.editorViewController,
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

            if let downView = try? MarkdownView(imagesStorage: imagesStorage, frame: self.view.frame, markdownString: markdownString, css: "", templateBundle: bundle) {
                downView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(downView)
            }
        }
        return
    }

    @IBAction func clickOnButton() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let evc = pageController.editorViewController
        else { return }

        evc.clickOnButton()
    }

    public func reloadPreview() {
        guard view.subviews.count > 0 else { return }

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
