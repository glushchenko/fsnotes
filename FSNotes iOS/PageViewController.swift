//
//  PageViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/3/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class PageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    override func viewDidLoad() {
        self.dataSource = self
        self.delegate = self
        
        // This sets up the first view that will show up on our page control
        if let firstViewController = orderedViewControllers.first {
            setViewControllers([firstViewController],
                               direction: .forward,
                               animated: false,
                               completion: nil)
        }
    }
    
    func newVc(viewController: String) -> UIViewController {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: viewController)
        
        if viewController == "editorViewController" {
            return UINavigationController(rootViewController: vc)
        }
        
        return vc
    }
    
    lazy var orderedViewControllers: [UIViewController] = {
        return [
            self.newVc(viewController: "listViewController"),
            self.newVc(viewController: "editorViewController")
        ]
    }()
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.index(of: viewController) else {
            return nil
        }
                
        let previousIndex = viewControllerIndex - 1
        
        // User is on the first view controller and swiped left to loop to
        // the last view controller.
        guard previousIndex >= 0 else {
            return orderedViewControllers.last
            // Uncommment the line below, remove the line above if you don't want the page control to loop.
            // return nil
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
            return orderedViewControllers.first
            // Uncommment the line below, remove the line above if you don't want the page control to loop.
            // return nil
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
        
        if previousViewControllers[0].isKind(of: UINavigationController.self) && completed {
            disableSwipe()
            
            guard
                let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
                let vc = pageController.orderedViewControllers[0] as? ViewController else {
                    return
            }
            
            if vc.shouldReloadNotes {
                vc.updateTable() {}
                vc.shouldReloadNotes = false
            }
            
        } else {
            enableSwipe()
        }
    }
    
    func switchToList() {
        self.dismiss(animated: true, completion: nil)
        setViewControllers([orderedViewControllers[0]], direction: .reverse, animated: true)
    }
    
    func switchToEditor() {
        setViewControllers([orderedViewControllers[1]], direction: .forward, animated: true)
    }
}
