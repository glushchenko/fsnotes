//
//  NotesCounterView.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 14.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

@IBDesignable
class NotesCounterView: NSView {
    
    private var visualEffectView: NSVisualEffectView?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        let effectView = NSVisualEffectView(frame: bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .behindWindow
        effectView.material = .contentBackground
        effectView.state = .followsWindowActiveState
        
        addSubview(effectView, positioned: .below, relativeTo: nil)
        visualEffectView = effectView
    }
}
