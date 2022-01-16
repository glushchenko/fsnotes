//
//  SwipeViewController.swift
//  SwipeBetweenViewControllers
//
//  Created by Marek Fořt on 11.03.16.
//  Copyright © 2016 Marek Fořt. All rights reserved.
//

import UIKit

public enum Side {
    case left, right
}

open class SwipeViewController: UINavigationController, UIPageViewControllerDelegate, UIScrollViewDelegate {
    public private(set) var pages: [UIViewController] = []
    public var startIndex: Int = 0 {
        didSet {
            guard pages.count > startIndex else { return }
            currentPageIndex = startIndex
            view.backgroundColor = pages[startIndex].view.backgroundColor
        }
    }

    public var selectionBarHeight: CGFloat = 0 {
        didSet {
            selectionBar.frame.size.height = selectionBarHeight
        }
    }

    public var selectionBarWidth: CGFloat = 0 {
        didSet {
            selectionBar.frame.size.width = selectionBarWidth
        }
    }

    public var selectionBarColor: UIColor = .black {
        didSet {
            selectionBar.backgroundColor = selectionBarColor
        }
    }

    public var buttonFont = UIFont.systemFont(ofSize: 18) {
        didSet {
            buttons.forEach { $0.titleLabel?.font = buttonFont }
        }
    }

    public var buttonColor: UIColor = .black {
        didSet {
            buttons.enumerated().filter { key, _ in currentPageIndex != key }.forEach { _, element in element.titleLabel?.textColor = buttonColor }
        }
    }

    public var selectedButtonColor: UIColor = .green {
        didSet {
            guard !buttons.isEmpty else { return }
            buttons[currentPageIndex].titleLabel?.textColor = selectedButtonColor
        }
    }

    public var navigationBarColor: UIColor = .white {
        didSet {
            navigationBar.barTintColor = navigationBarColor
        }
    }

    public var leftBarButtonItem: UIBarButtonItem? {
        didSet {
            pageController.navigationItem.leftBarButtonItem = leftBarButtonItem
        }
    }

    public var rightBarButtonItem: UIBarButtonItem? {
        didSet {
            pageController.navigationItem.rightBarButtonItem = rightBarButtonItem
        }
    }

    public var bottomOffset: CGFloat = 0
    public var equalSpaces: Bool = true
    public var buttonsWithImages: [SwipeButtonWithImage] = []
    public var offset: CGFloat = 40
    public let pageController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    public var currentPageIndex = 0

    public private(set) var buttons: [UIButton] = []
    private var barButtonItemWidth: CGFloat = 0
    private var navigationBarHeight: CGFloat = 0
    private weak var selectionBar: UIView!
    private var totalButtonWidth: CGFloat = 0
    private var finalPageIndex = -1
    private var indexNotIncremented = true
    private var pageScrollView = UIScrollView()
    private var animationFinished = true
    private var leftSubtract: CGFloat = 0
    private var firstWillAppearOccured = false
    private var spaces: [CGFloat] = []
    private var x: CGFloat = 0
    private var selectionBarOriginX: CGFloat = 0
    private weak var navigationView: UIView!

    private var previewLoadingClosure: (()->())?
    private var scrollDidMoveClosure: ((Int) -> Void)?
    private var lastIndex = 0

    public init(pages: [UIViewController]) {
        super.init(nibName: nil, bundle: nil)
        self.pages = pages

        setViewControllers([pageController], animated: false)
        pageController.navigationController?.navigationItem.leftBarButtonItem = leftBarButtonItem
        pageController.navigationController?.setNavigationBarHidden(true, animated: false)

        pageController.delegate = self
        pageController.dataSource = self
        if let scrollView = pageController.view.subviews.compactMap({ $0 as? UIScrollView }).first {
            scrollView.delegate = self
        }

        barButtonItemWidth = pageController.navigationController?.navigationBar.topItem?.titleView?.layoutMargins.left ?? 0

        navigationBar.isTranslucent = false

        let navigationView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: navigationBar.frame.height))
        navigationView.backgroundColor = navigationBarColor
        pageController.navigationController?.navigationBar.topItem?.titleView = navigationView
        self.navigationView = navigationView
        barButtonItemWidth = navigationBar.topItem?.titleView?.layoutMargins.left ?? 0

        addPages()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Method is called when `viewWillAppear(_:)` is called for the first time
    func viewWillFirstAppear(_: Bool) {
        updateButtonsAppearance()
        updateButtonsLayout()
        updateSelectionBarFrame()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !firstWillAppearOccured {
            viewWillFirstAppear(animated)
            firstWillAppearOccured = true
        }
    }

    private func setTitleLabel(_ page: UIViewController, font: UIFont, color: UIColor, button: UIButton) {
        // Title font and color
        guard let pageTitle = page.title else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedTitle = NSAttributedString(string: pageTitle, attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: UIControl.State())

        guard let titleLabel = button.titleLabel else { return }
        titleLabel.textColor = color

        titleLabel.sizeToFit()

        button.frame = titleLabel.frame
    }

    private func createSelectionBar() {
        let selectionBar = UIView()
        self.selectionBar = selectionBar

        // SelectionBar
        updateSelectionBarFrame()
        selectionBar.backgroundColor = selectionBarColor
        navigationView.addSubview(selectionBar)
    }

    private func updateSelectionBarFrame() {
        let originY = navigationView.frame.height - selectionBarHeight - bottomOffset
        selectionBar.frame = CGRect(x: selectionBarOriginX, y: originY, width: selectionBarWidth, height: selectionBarHeight)
        selectionBar.frame.origin.x -= leftSubtract
    }

    private func addPages() {
        view.backgroundColor = pages[currentPageIndex].view.backgroundColor

        createButtons()
        createSelectionBar()

        // Init of initial view controller
        guard currentPageIndex >= 0 else { return }
        let initialViewController = pages[currentPageIndex]
        pageController.setViewControllers([initialViewController], direction: .forward, animated: true, completion: nil)

        // Select button of initial view controller - change to selected image
        buttons[currentPageIndex].isSelected = true
    }

    private func createButtons() {
        buttons = (1 ... pages.count).map {
            let button = UIButton()
            button.tag = $0
            navigationView.addSubview(button)
            return button
        }
    }

    private func updateButtonsAppearance() {
        totalButtonWidth = 0
        buttons.enumerated().forEach { tag, button in
            if buttonsWithImages.isEmpty {
                setTitleLabel(pages[tag], font: buttonFont, color: buttonColor, button: button)
            } else {
                // Getting buttnWithImage struct from array
                let buttonWithImage = buttonsWithImages[tag]
                // Normal image
                button.setImage(buttonWithImage.image, for: UIControl.State())
                // Selected image
                button.setImage(buttonWithImage.selectedImage, for: .selected)
                // Button tint color
                button.tintColor = buttonColor

                // Button size
                if let size = buttonWithImage.size {
                    button.frame.size = size
                }
            }
            totalButtonWidth += button.frame.width
        }
    }

    private func updateButtonsLayout() {
        let totalButtonWidth = buttons.reduce(0) { $0 + $1.frame.width }
        var space: CGFloat = 0
        var width: CGFloat = 0

        if equalSpaces {
            // Space between buttons
            x = (view.frame.width - 2 * offset - totalButtonWidth) / CGFloat(buttons.count + 1)
        } else {
            // Space reserved for one button (with label and spaces around it)
            space = (view.frame.width - 2 * offset) / CGFloat(buttons.count)
        }

        for button in buttons {
            let buttonHeight = button.frame.height
            let buttonWidth = button.frame.width

            let originY = navigationView.frame.height - selectionBarHeight - bottomOffset - buttonHeight - 3
            var originX: CGFloat = 0

            if equalSpaces {
                originX = x * CGFloat(button.tag) + width + offset - barButtonItemWidth
                width += buttonWidth
            } else {
                let buttonSpace = space - buttonWidth
                originX = buttonSpace / 2 + width + offset - barButtonItemWidth
                width += buttonWidth + space - buttonWidth
                spaces.append(buttonSpace)
            }

            if button.tag == currentPageIndex + 1 {
                guard let titleLabel = button.titleLabel else { continue }
                selectionBarOriginX = originX - (selectionBarWidth - buttonWidth) / 2
                titleLabel.textColor = selectedButtonColor
            }

            button.frame = CGRect(x: originX, y: originY, width: buttonWidth, height: buttonHeight)

            addFunction(button)
        }

        updateLeftSubtract()
        buttons.forEach { $0.frame.origin.x -= leftSubtract }
    }

    private func updateLeftSubtract() {
        guard let firstButton = buttons.first else { return }
        let convertedXOrigin = firstButton.convert(firstButton.frame.origin, to: view).x
        let barButtonWidth: CGFloat = equalSpaces ? 0 : barButtonItemWidth
        let leftSubtract: CGFloat = (convertedXOrigin - offset + barButtonWidth) / 2 - x / 2
        self.leftSubtract = leftSubtract
    }

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let xFromCenter = view.frame.width - scrollView.contentOffset.x

        var width: CGFloat = 0
        let border = view.frame.width - 1

        guard currentPageIndex >= 0, currentPageIndex < buttons.endIndex else { return }

        // Ensuring currentPageIndex is not changed twice
        if -border ... border ~= xFromCenter {
            indexNotIncremented = true
        }

        // Resetting finalPageIndex for switching tabs
        if xFromCenter == 0 {
            finalPageIndex = -1
            animationFinished = true
        }

        // Going right
        if xFromCenter <= -view.frame.width, indexNotIncremented, currentPageIndex < buttons.endIndex - 1 {
            view.backgroundColor = pages[currentPageIndex + 1].view.backgroundColor
            currentPageIndex += 1
            indexNotIncremented = false
        }

        // Going left
        else if xFromCenter >= view.frame.width, indexNotIncremented, currentPageIndex >= 1 {
            view.backgroundColor = pages[currentPageIndex - 1].view.backgroundColor
            currentPageIndex -= 1
            indexNotIncremented = false
        }

        if buttonColor != selectedButtonColor {
            changeButtonColor(xFromCenter)
        }

        // Call back preview request
        if currentPageIndex == 1 && xFromCenter < 0, let previewClosure = previewLoadingClosure {
            previewClosure()
            previewLoadingClosure = nil
        }

        // Call back did move
        if xFromCenter == 0 && currentPageIndex != lastIndex {
            lastIndex = currentPageIndex
            scrollDidMoveClosure?(currentPageIndex)
        }

        for button in buttons {
            var originX: CGFloat = 0
            var space: CGFloat = 0

            if equalSpaces {
                originX = x * CGFloat(button.tag) + width
                width += button.frame.width
            } else {
                space = spaces[button.tag - 1]
                originX = space / 2 + width
                width += button.frame.width + space
            }

            let selectionBarOriginX = originX - (selectionBarWidth - button.frame.width) / 2 + offset - barButtonItemWidth - leftSubtract

            // Get button with current index
            guard button.tag == currentPageIndex + 1
            else { continue }

            var nextButton = UIButton()
            var nextSpace: CGFloat = 0

            if xFromCenter < 0, button.tag < buttons.count {
                nextButton = buttons[button.tag]
                if equalSpaces == false {
                    nextSpace = spaces[button.tag]
                }
            } else if xFromCenter > 0, button.tag != 1 {
                nextButton = buttons[button.tag - 2]
                if equalSpaces == false {
                    nextSpace = spaces[button.tag - 2]
                }
            }

            var newRatio: CGFloat = 0

            if equalSpaces {
                let expression = 2 * x + button.frame.width - (selectionBarWidth - nextButton.frame.width) / 2
                newRatio = view.frame.width / (expression - (x - (selectionBarWidth - button.frame.width) / 2))
            } else {
                let expression = button.frame.width + space / 2 + (selectionBarWidth - button.frame.width) / 2
                newRatio = view.frame.width / (expression + nextSpace / 2 - (selectionBarWidth - nextButton.frame.width) / 2)
            }

            selectionBar.frame = CGRect(x: selectionBarOriginX - (xFromCenter / newRatio), y: selectionBar.frame.origin.y, width: selectionBarWidth, height: selectionBarHeight)
            return
        }
    }

    // Triggered when selected button in navigation view is changed
    func scrollToNextViewController(_ index: Int) {
        let currentViewControllerIndex = currentPageIndex

        // Comparing index (i.e. tab where user is going to) and when compared, we can now know what direction we should go
        // Index is on the right
        if index > currentViewControllerIndex {
            // loop - if user goes from tab 1 to tab 3 we want to have tab 2 in animation
            for viewControllerIndex in currentViewControllerIndex ... index {
                let destinationViewController = pages[viewControllerIndex]
                pageController.setViewControllers([destinationViewController], direction: .forward, animated: true, completion: nil)
            }
        }
        // Index is on the left
        else {
            for viewControllerIndex in (index ... currentViewControllerIndex).reversed() {
                let destinationViewController = pages[viewControllerIndex]
                pageController.setViewControllers([destinationViewController], direction: .reverse, animated: true, completion: nil)
            }
        }
    }

    @objc func switchTabs(_ sender: UIButton) {
        let index = sender.tag - 1

        // Can't animate twice to the same controller (otherwise weird stuff happens)
        guard index != finalPageIndex, index != currentPageIndex, animationFinished else { return }

        animationFinished = false
        finalPageIndex = index
        scrollToNextViewController(index)
    }

    func addFunction(_ button: UIButton) {
        button.addTarget(self, action: #selector(switchTabs(_:)), for: .touchUpInside)
    }

    func changeButtonColor(_ xFromCenter: CGFloat) {
        // Change color of button before animation finished (i.e. colour changes even when the user is between buttons

        let viewWidthHalf = view.frame.width / 2
        let border = view.frame.width - 1
        let halfBorder = view.frame.width / 2 - 1

        // Going left, next button selected
        if viewWidthHalf ... border ~= xFromCenter, currentPageIndex > 0 {
            let button = buttons[currentPageIndex - 1]
            let previousButton = buttons[currentPageIndex]

            button.titleLabel?.textColor = selectedButtonColor
            previousButton.titleLabel?.textColor = buttonColor

            button.isSelected = true
            previousButton.isSelected = false
        }

        // Going right, current button selected
        else if 0 ... halfBorder ~= xFromCenter, currentPageIndex > 1 {
            let button = buttons[currentPageIndex]
            let previousButton = buttons[currentPageIndex - 1]

            button.titleLabel?.textColor = selectedButtonColor
            previousButton.titleLabel?.textColor = buttonColor

            button.isSelected = true
            previousButton.isSelected = false
        }

        // Going left, current button selected
        else if -halfBorder ... 0 ~= xFromCenter, currentPageIndex < buttons.endIndex - 1 {
            let previousButton = buttons[currentPageIndex + 1]
            let button = buttons[currentPageIndex]

            button.titleLabel?.textColor = selectedButtonColor
            previousButton.titleLabel?.textColor = buttonColor

            button.isSelected = true
            previousButton.isSelected = false
        }

        // Going right, next button selected
        else if -border ... -viewWidthHalf ~= xFromCenter, currentPageIndex < buttons.endIndex - 1 {
            let button = buttons[currentPageIndex + 1]
            let previousButton = buttons[currentPageIndex]

            button.titleLabel?.textColor = selectedButtonColor
            previousButton.titleLabel?.textColor = buttonColor

            button.isSelected = true
            previousButton.isSelected = false
        }
    }
}

extension SwipeViewController: UIPageViewControllerDataSource {
    // Swiping left
    public func pageViewController(_: UIPageViewController,
                                   viewControllerBefore viewController: UIViewController) -> UIViewController? {
        // Get current view controller index
        guard let viewControllerIndex = pages.firstIndex(of: viewController) else { return nil }

        let previousIndex = viewControllerIndex - 1

        // Making sure the index doesn't get bigger than the array of view controllers
        guard previousIndex >= 0, pages.count > previousIndex else { return nil }

        return pages[previousIndex]
    }

    // Swiping right
    public func pageViewController(_: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        // Get current view controller index
        guard let viewControllerIndex = pages.firstIndex(of: viewController) else { return nil }

        let nextIndex = viewControllerIndex + 1

        // Making sure the index doesn't get bigger than the array of view controllers
        guard pages.count > nextIndex else { return nil }

        return pages[nextIndex]
    }

    public func onPreviewLoadingCallback(_ closure: @escaping () -> Void) {
        previewLoadingClosure = closure
    }

    public func scrollDidMoveToControllerIndex(_ closure: @escaping (Int) -> Void) {
        scrollDidMoveClosure = closure
    }
}

public struct SwipeButtonWithImage {
    var size: CGSize?
    var image: UIImage?
    var selectedImage: UIImage?

    public init(image: UIImage?, selectedImage: UIImage?, size: CGSize?) {
        self.image = image
        self.selectedImage = selectedImage
        self.size = size
    }
}
