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
    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = Colors.buttonText
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.navigationBar.mixedBackgroundColor = Colors.Header

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(returnBack))

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)

        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }

    @objc public func returnBack() {
        if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController {
            clear()
            pageController.switchToList()
        }
    }

    @objc func rotated() {
        self.reloadPreview()
    }

    public func loadPreview() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let evc = pageController.editorViewController,
            let note = evc.note
        else { return }

        setTitle(text: note.title)

        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)

        let markdownString = note.content.string
        do {
            var imagesStorage = note.project.url

            if note.isTextBundle() {
                imagesStorage = note.url
            }

            if let downView = try? MarkdownView(imagesStorage: imagesStorage, frame: self.view.frame, markdownString: markdownString, css: "", templateBundle: bundle) {
                downView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(downView)
            }
        }
        return
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
        navigationItem.titleView = button
        navigationItem.title = text
    }

    public func clear() {
        setTitle(text: "")

        for sub in self.view.subviews {
            if sub.isKind(of: MarkdownView.self) {
                sub.removeFromSuperview()
            }
        }
    }
}
