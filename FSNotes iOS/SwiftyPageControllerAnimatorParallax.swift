//
//  PagesViewControllerAnimator.swift
//  ContainerControllerTest
//
//  Created by Alexander on 8/3/17.
//  Copyright © 2017 CryptoTicker. All rights reserved.
//

import Foundation
import UIKit

open class SwiftyPageControllerAnimatorParallax: SwiftyPageControllerAnimatorProtocol {
    
    private var _animationProgress: Float!
    private var _animationSpeed: Float = 3.2
    private var timer: Timer!
    private var fromControllerAnimationIdentifier = "from.controller.animation.position.x"
    private var toControllerAnimationIdentifier = "to.controller.animation.position.x"
    
    public var animationProgress: Float {
        get {
            return _animationProgress
        }
        
        set {
            _animationProgress = newValue
        }
    }
    
    public var animationSpeed: Float {
        get {
            return _animationSpeed
        }
        
        set {
            _animationSpeed = newValue
        }
    }
    
    public var isEnabledOpacity = false
    
    public func setupAnimation(fromController: UIViewController, toController: UIViewController, panGesture: UIPanGestureRecognizer, animationDirection: SwiftyPageController.AnimationDirection) {
        let speed = panGesture.state != .changed ? animationSpeed : 0.0
        
        // position animation
        let animationPositionToController = CABasicAnimation(keyPath: "position.x")
        animationPositionToController.duration = animationDuration
        animationPositionToController.fromValue = animationDirection == .left ? (toController.view.frame.width * 1.5) : (-toController.view.frame.width / 2.0)
        animationPositionToController.toValue = toController.view.frame.width / 2.0
        animationPositionToController.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        
        toController.view.layer.add(animationPositionToController, forKey: toControllerAnimationIdentifier)
        
        let animationPositionFromController = animationPositionToController
        animationPositionFromController.fromValue = fromController.view.layer.position.x
        animationPositionFromController.toValue = animationDirection == .left ? (0.0) : (toController.view.frame.width)
        
        fromController.view.layer.add(animationPositionFromController, forKey: fromControllerAnimationIdentifier)
        
        // set speed
        toController.view.layer.speed = speed
        fromController.view.layer.speed = speed
    }
    
    public func didFinishAnimation(fromController: UIViewController, toController: UIViewController) {
        // remove animations
        toController.view.layer.removeAnimation(forKey: toControllerAnimationIdentifier)
        fromController.view.layer.removeAnimation(forKey: fromControllerAnimationIdentifier)
    }
    
}
