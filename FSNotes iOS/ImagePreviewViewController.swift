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
import CropViewController

class ImagePreviewViewController: UIViewController, CropViewControllerDelegate {
    @IBOutlet weak var imageScrollView: ImageScrollView!

    public var image: UIImage?
    public var url: URL?
    public var note: Note?
    public var imageUrls = [URL]()

    private var currentIndex = 0

    @IBOutlet weak var bottomSafeView: UIView!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var navItem: UINavigationItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarBackground), name: NSNotification.Name(rawValue: NightNightThemeChangeNotification), object: nil)

        navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationBar.mixedTintColor = Colors.buttonText
        navigationBar.mixedBarTintColor = Colors.Header
        navigationBar.mixedBackgroundColor = Colors.Header
        bottomSafeView.mixedBackgroundColor = Colors.Header

        updateNavigationBarBackground()

        let doneString = NSLocalizedString("Cancel", comment: "")

        let moreButton = UIButton(frame: CGRect(x: 0, y: 0, width: 35, height: 35))
        moreButton.setBackgroundImage(UIImage(named: "shareAction")!.imageWithColor(color1: .white), for: .normal)

        navItem.leftBarButtonItem = UIBarButtonItem(title: doneString, style: .done, target: self, action: #selector(done))

        let shareButton = UIBarButtonItem.menuButton(self, action: #selector(share), imageName: "shareButton", size: CGSize(width: 26, height: 26), tintColor: nil)

        let cropButton = UIBarButtonItem.menuButton(self, action: #selector(crop), imageName: "cropButton", size: CGSize(width: 30, height: 30), tintColor: nil)

        let dropButton = UIBarButtonItem.menuButton(self, action: #selector(trashBin), imageName: "trashButton", size: CGSize(width: 30, height: 30), tintColor: nil)

        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        space.width = 20

        navItem.rightBarButtonItems = [shareButton, space, cropButton, space, dropButton]

        DispatchQueue.main.async {
            self.rotated()
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognizer(_:)))
        tapGesture.numberOfTapsRequired = 1
        imageScrollView.addGestureRecognizer(tapGesture)

        var urls = [URL]()
        if let result = note?.getAllImages() {
            for item in result {
                urls.append(item.url)
            }
        }

        imageUrls = urls

        if let url = url, let index = imageUrls.firstIndex(of: url) {
            currentIndex = index
        }
    }

    @objc public func tapGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        let center = gestureRecognizer.location(in: gestureRecognizer.view)
        var selectedUrl: URL?

        if let zoomView = imageScrollView.zoomView, zoomView.frame.width > view.frame.width {
            return
        }

        if center.x < 40 {
            selectedUrl = prevImage()
        }

        if center.x > imageScrollView.frame.width - 40 {
            selectedUrl = nextImage()
        }

        if let url = selectedUrl, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            imageScrollView.display(image: image)
            self.image = image
            self.url = selectedUrl
        }
    }

    private func nextImage() -> URL {
        currentIndex += 1

        if currentIndex >= imageUrls.count {
            currentIndex = 0
        }

        return imageUrls[currentIndex]
    }

    private func prevImage() -> URL {
        currentIndex -= 1

        if currentIndex < 0 {
            currentIndex = imageUrls.count - 1
        }

        return imageUrls[currentIndex]
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

    @IBAction func crop() {
        guard let image = image else { return }
        let cropViewController = CropViewController(image: image)
        cropViewController.delegate = self
        cropViewController.hidesNavigationBar = false
        cropViewController.modalPresentationStyle = .fullScreen
        cropViewController.modalTransitionStyle = .crossDissolve
        cropViewController.transitioningDelegate = nil
        present(cropViewController, animated: true, completion: nil)
    }

    @IBAction func trashBin() {
        let messageText = NSLocalizedString("Are you sure you want to delete this image?", comment: "")

        let alertController = UIAlertController(title: NSLocalizedString("Picture removing", comment: ""), message: messageText, preferredStyle: .alert)

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            if let url = self.url, let note = self.note {
                let evc = UIApplication.getEVC()

                if let imageRange = evc.editArea.textStorage.getImageRange(url: url) {
                    evc.editArea.selectedRange = imageRange
                    evc.editArea.insertText("")

                    if let copy = evc.editArea.attributedText.copy() as? NSAttributedString {
                        note.saveSync(copy: copy)
                        note.invalidateCache()
                    }

                    UIApplication.getVC().notesTable.reloadRows(notes: [note])
                }
            }

            self.dismiss(animated: true)
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }

    @objc func rotated() {
        imageScrollView.setup()
        imageScrollView.imageContentMode = .aspectFit
        imageScrollView.initialOffset = .center
        imageScrollView.display(image: image!)
    }

    @objc public func updateNavigationBarBackground() {
        if #available(iOS 13.0, *) {
            var color = UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00)
            if NightNight.theme == .night {
                color = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            }

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }

    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        if let url = url {
            try? image.jpegData(compressionQuality: 0.6)?.write(to: url)
            let cacheImage = NoteAttachment.getCacheUrl(from: url, prefix: "ThumbnailsBigInline")

            if let path = cacheImage?.path, FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.removeItem(at: cacheImage!)
            }

            UIApplication.getEVC().refill()
        }

        self.imageScrollView.display(image: image)

        UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
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
