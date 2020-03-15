//
//  ViewController.swift
//  ImageScrollViewDemo
//
//  Created by Nguyen Cong Huy on 3/5/16.
//  Copyright © 2016 Nguyen Cong Huy. All rights reserved.
//

import UIKit
import AudioToolbox
import NightNight

class ImagePreviewViewController: UIViewController {
    @IBOutlet weak var imageScrollView: ImageScrollView!

    public var image: UIImage?
    public var url: URL?

    @IBOutlet weak var navigation: UINavigationBar!
    @IBOutlet weak var navigationBar: UINavigationItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        imageScrollView.setup()
        imageScrollView.imageContentMode = .aspectFit
        imageScrollView.initialOffset = .center
        imageScrollView.display(image: image!)

        navigation.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

        let doneString = NSLocalizedString("Done", comment: "")
        let moreButton = UIButton(frame: CGRect(x: 0, y: 0, width: 35, height: 35))
        moreButton.setBackgroundImage(UIImage(named: "share"), for: .normal)
        navigationBar.rightBarButtonItem = UIBarButtonItem.menuButton(self, action: #selector(share), imageName: "share", size: CGSize(width: 24, height: 24), tintColor: nil)
        navigationBar.leftBarButtonItem = UIBarButtonItem(title: doneString, style: .done, target: self, action: #selector(done))
    }

    @IBAction func share() {
        guard let url = self.url else { return }

        AudioServicesPlaySystemSound(1519)

        let objectsToShare = [url] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.excludedActivityTypes = [UIActivity.ActivityType.addToReadingList]

        present(activityVC, animated: true, completion: nil)
    }

    @IBAction func done() {
        dismiss(animated: true, completion: nil)
    }
}

extension UIBarButtonItem {

    static func menuButton(_ target: Any?,
                           action: Selector,
                           imageName: String,
                           size:CGSize = CGSize(width: 32, height: 32),
                           tintColor:UIColor?) -> UIBarButtonItem
    {
        let button = UIButton(type: .system)
        button.tintColor = tintColor
        button.setImage(UIImage(named: imageName), for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: button)
        menuBarItem.customView?.translatesAutoresizingMaskIntoConstraints = false
        menuBarItem.customView?.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        menuBarItem.customView?.widthAnchor.constraint(equalToConstant: size.width).isActive = true

        return menuBarItem
    }
}
