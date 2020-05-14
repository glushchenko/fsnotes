//
//  PageViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/3/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class PageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, UIScrollViewDelegate {

    private var startOffset = CGFloat(0)
    private var swipeEnded = false

    public var mainViewController: ViewController? = nil
    public var editorViewController: EditorViewController? = nil
    public var previewViewController: PreviewViewController? = nil

    override func viewDidLoad() {
        self.dataSource = self
        self.delegate = self

        // This sets up the first view that will show up on our page control
        if let firstViewController = orderedViewControllers.first {
            //DispatchQueue.main.async {
                self.setViewControllers([firstViewController],
                               direction: .forward,
                               animated: false,
                               completion: nil)
            //}
        }

        if let subView = self.view.subviews.first as? UIScrollView {
            subView.delegate = self
        }
    }
    
    func newVc(viewController: String) -> UIViewController {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: viewController)

        if viewController == "editorViewController" {
            editorViewController = vc as? EditorViewController
            return UINavigationController(rootViewController: editorViewController!)
        }

        if viewController == "previewViewController" {
            previewViewController = vc as? PreviewViewController
            return UINavigationController(rootViewController: previewViewController!)
        }

        mainViewController = vc as? ViewController
        return vc
    }
    
    lazy var orderedViewControllers: [UIViewController] = {
        return [
            self.newVc(viewController: "listViewController"),
            self.newVc(viewController: "editorViewController"),
            self.newVc(viewController: "previewViewController")
        ]
    }()
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.firstIndex(of: viewController) else {
            return nil
        }

        let previousIndex = viewControllerIndex - 1
        
        // User is on the first view controller and swiped left to loop to
        // the last view controller.
        guard previousIndex >= 0 else {
            //return orderedViewControllers.last
            // Uncommment the line below, remove the line above if you don't want the page control to loop.
            return nil
        }
        
        guard orderedViewControllers.count > previousIndex else {
            return nil
        }
        
        return orderedViewControllers[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.index(of: viewController) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        let orderedViewControllersCount = orderedViewControllers.count
        
        // User is on the last view controller and swiped right to loop to
        // the first view controller.
        guard orderedViewControllersCount != nextIndex else {
            //return orderedViewControllers.first
            // Uncommment the line below, remove the line above if you don't want the page control to loop.
            return nil
        }
        
        guard orderedViewControllersCount > nextIndex else {
            return nil
        }
        
        return orderedViewControllers[nextIndex]
    }

    func disableSwipe() {
        for view in self.view.subviews {
            if let subView = view as? UIScrollView {
                subView.isScrollEnabled = false
            }
        }
    }
    
    func enableSwipe() {
        for view in self.view.subviews {
            if let subView = view as? UIScrollView {
                subView.isScrollEnabled = true
            }
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {

        guard completed, let current = self.viewControllers?.first else { return }

        if let nav = current as? UINavigationController {
            if let preview = nav.viewControllers.first as? PreviewViewController {
                preview.loadPreview()
                return
            }
        }

        previewViewController?.clear()

        if current.isKind(of: UINavigationController.self) {
            DispatchQueue.main.async {
                self.enableSwipe()
            }
        } else {
            DispatchQueue.main.async {
                self.disableSwipe()
            }
        }
    }
    
    func switchToList(completion: (() -> ())? = nil) {
        self.setViewControllers([self.orderedViewControllers[0]], direction: .reverse, animated: true) { _ in

            guard let completion = completion else { return }
            completion()
        }
    }
    
    func switchToEditor(completion: (() -> ())? = nil) {
        self.setViewControllers([self.orderedViewControllers[1]], direction: .forward, animated: true) { _ in
            
            guard let completion = completion else { return }
            completion()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var direction = 0

        if startOffset < scrollView.contentOffset.x {
            direction = 1
        }else if startOffset > scrollView.contentOffset.x {
            direction = -1
        }

        let positionFromStartOfCurrentPage = abs(startOffset - scrollView.contentOffset.x)
        let percent = positionFromStartOfCurrentPage /  self.view.frame.width

        if let view = self.viewControllers?.first, view.isKind(of: UINavigationController.self) && direction == -1, !self.swipeEnded {
            self.orderedViewControllers[0].view.alpha = percent + 0.3
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.swipeEnded = false
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.startOffset = scrollView.contentOffset.x
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.swipeEnded = true
        self.fadeOutController()
    }

    private func fadeOutController() {
        DispatchQueue.main.async {
            UIView.beginAnimations("pager", context: nil)
            UIView.setAnimationDuration(0.3)
            UIView.setAnimationBeginsFromCurrentState(true)
            self.orderedViewControllers[0].view.alpha = 1
            UIView.commitAnimations()
        }
    }
}
