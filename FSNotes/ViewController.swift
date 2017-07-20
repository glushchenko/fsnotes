//
//  ViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTextViewDelegate,
NSTextFieldDelegate {
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var search: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.delegate = self
        search.delegate = self
        textView.textContainerInset = NSMakeSize(0, 5);
        
        
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func textDidChange(_ notification: Notification) {
        print(textView.string)
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        print(search.stringValue)
    }
    
    @IBAction func demo(_ sender: NSTextField) {
        print(222)
    }
}

