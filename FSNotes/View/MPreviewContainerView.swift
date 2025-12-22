//
//  MPreviewContainerView.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 21.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import AppKit

class MPreviewContainerView: NSView {
    
    // UI Elements
    public var webView: MPreviewView!
    private var findPanel: MPreviewFindPanel!
    private var findPanelHeightConstraint: NSLayoutConstraint!
    
    // Search state
    private var currentMatchIndex = 0
    private var totalMatches = 0
    public var isFindPanelVisible = false
    
    // MARK: - Initialization
    init(frame: NSRect, note: Note, closure: MPreviewViewClosure?, force: Bool = false) {
        super.init(frame: frame)
        setupWebView(note: note, closure: closure, force: force)
        setupFindPanel()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: findPanel.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupWebView(note: Note, closure: MPreviewViewClosure?, force: Bool) {
        webView = MPreviewView(frame: bounds, note: note, closure: closure, force: force)
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
    }
    
    private func setupFindPanel() {
        findPanel = MPreviewFindPanel()
        findPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(findPanel)
        
        NSLayoutConstraint.activate([
            findPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            findPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            findPanel.topAnchor.constraint(equalTo: topAnchor)
        ])
        
        findPanel.isHidden = true
        findPanel.panelHeightConstraint.constant = 0
    
        // Callbacks
        findPanel.onSearch = { [weak self] searchText in
            self?.performSearch(searchText)
        }
        
        findPanel.onNext = { [weak self] in
            self?.findNext()
        }
        
        findPanel.onPrevious = { [weak self] in
            self?.findPrevious()
        }
        
        findPanel.onDone = { [weak self] in
            self?.hideFindPanel()
        }
    }
    
    // MARK: - Public API
    
    var previewView: MPreviewView {
        return webView
    }
    
    func showFindPanel() {
        window?.makeFirstResponder(self)
        
        isFindPanelVisible = true
        
        let pasteboard = NSPasteboard(name: .find)
        if let searchText = pasteboard.string(forType: .string) {
            pasteboard.clearContents()
            findPanel.searchField.stringValue = searchText
            findPanel.onSearch?(searchText)
        }
        
        findPanel.show()
    }

    func hideFindPanel() {
        isFindPanelVisible = false
        
        findPanel.hide()
        clearHighlights()
    }
    
    func toggleFindPanel() {
        if isFindPanelVisible {
            hideFindPanel()
        } else {
            showFindPanel()
        }
    }
    
    // MARK: - Search Implementation
    
    private func performSearch(_ searchText: String) {
        guard !searchText.isEmpty else {
            clearHighlights()
            return
        }
        
        let escapedText = searchText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let jsCode = """
        (function() {
            document.querySelectorAll('.mpreview-find-highlight').forEach(el => {
                var parent = el.parentNode;
                parent.replaceChild(document.createTextNode(el.textContent), el);
                parent.normalize();
            });
            
            var searchText = '\(escapedText)';
            if (searchText.length === 0) return 0;
            
            var escapedSearch = searchText.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
            var regex = new RegExp('(' + escapedSearch + ')', 'gi');
            
            var walker = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_TEXT,
                {
                    acceptNode: function(node) {
                        if (node.parentNode.nodeName === 'SCRIPT' || 
                            node.parentNode.nodeName === 'STYLE' ||
                            node.parentNode.classList.contains('mpreview-find-highlight')) {
                            return NodeFilter.FILTER_REJECT;
                        }
                        return NodeFilter.FILTER_ACCEPT;
                    }
                },
                false
            );
            
            var nodesToReplace = [];
            while(walker.nextNode()) {
                var node = walker.currentNode;
                if(regex.test(node.textContent)) {
                    nodesToReplace.push(node);
                }
            }
            
            var matchCount = 0;
            nodesToReplace.forEach(function(node) {
                var text = node.textContent;
                var matches = text.match(regex);
                if (!matches) return;
                
                var fragment = document.createDocumentFragment();
                var lastIndex = 0;
                
                var tempText = text;
                while(true) {
                    var match = regex.exec(tempText);
                    if (!match) break;
                    
                    var index = match.index;
                    
                    if (index > lastIndex) {
                        fragment.appendChild(document.createTextNode(tempText.substring(lastIndex, index)));
                    }
                    
                    var mark = document.createElement('mark');
                    mark.className = 'mpreview-find-highlight';
                    mark.setAttribute('data-index', matchCount);
                    mark.textContent = match[0];
                    fragment.appendChild(mark);
                    
                    matchCount++;
                    lastIndex = index + match[0].length;
                }
                
                if (lastIndex < text.length) {
                    fragment.appendChild(document.createTextNode(tempText.substring(lastIndex)));
                }
                
                node.parentNode.replaceChild(fragment, node);
            });
            
            var firstMatch = document.querySelector('.mpreview-find-highlight');
            if(firstMatch) {
                firstMatch.classList.add('current-match');
                firstMatch.scrollIntoView({behavior: 'smooth', block: 'center'});
            }
            
            return matchCount;
        })();
        """
        
        webView.evaluateJavaScript(jsCode) { [weak self] result, error in
            if error != nil {
                print("Search error: \\(error)")
            }
            
            if let count = result as? Int {
                self?.totalMatches = count
                self?.currentMatchIndex = count > 0 ? 1 : 0
                self?.findPanel.updateStatus(current: self?.currentMatchIndex ?? 0,
                                            total: self?.totalMatches ?? 0)
            }
        }
        
        injectHighlightStyles()
    }
    
    func getSelectedText(completion: @escaping (String?) -> Void) {
        let javascript = "window.getSelection().toString()"
        
        webView.evaluateJavaScript(javascript) { (result, error) in
            if let error = error {
                print("Error: \(error)")
                completion(nil)
            } else {
                completion(result as? String)
            }
        }
    }
    
    private func injectHighlightStyles() {
        let css = """
        mark.mpreview-find-highlight {
            background-color: rgba(255, 255, 0, 0.35);
            color: inherit;
            padding: 1px 0;
            border-radius: 2px;
        }
        mark.mpreview-find-highlight.current-match {
            background-color: rgba(255, 143, 0, 0.8) !important;
            outline: 2px solid rgba(255, 100, 0, 0.6);
        }
        """
        
        let escapedCSS = css
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "'", with: "\\'")
        
        let jsCode = """
        (function() {
            var style = document.getElementById('mpreview-find-style');
            if(!style) {
                style = document.createElement('style');
                style.id = 'mpreview-find-style';
                document.head.appendChild(style);
            }
            style.innerHTML = '\(escapedCSS)';
        })();
        """
        
        webView.evaluateJavaScript(jsCode)
    }
    
    public func findNext() {
        guard totalMatches > 0 else { return }
        
        let jsCode = """
        (function() {
            var marks = document.querySelectorAll('.mpreview-find-highlight');
            if(marks.length === 0) return 0;
            
            var current = document.querySelector('.current-match');
            if(current) {
                current.classList.remove('current-match');
            }
            
            var currentIndex = current ? Array.from(marks).indexOf(current) : -1;
            var nextIndex = (currentIndex + 1) % marks.length;
            
            marks[nextIndex].classList.add('current-match');
            marks[nextIndex].scrollIntoView({behavior: 'smooth', block: 'center'});
            
            return nextIndex + 1;
        })();
        """
        
        webView.evaluateJavaScript(jsCode) { [weak self] result, error in
            if let index = result as? Int {
                self?.currentMatchIndex = index
                self?.findPanel.updateStatus(current: index, total: self?.totalMatches ?? 0)
            }
        }
    }
    
    private func findPrevious() {
        guard totalMatches > 0 else { return }
        
        let jsCode = """
        (function() {
            var marks = document.querySelectorAll('.mpreview-find-highlight');
            if(marks.length === 0) return 0;
            
            var current = document.querySelector('.current-match');
            if(current) {
                current.classList.remove('current-match');
            }
            
            var currentIndex = current ? Array.from(marks).indexOf(current) : 0;
            var prevIndex = currentIndex - 1;
            if(prevIndex < 0) prevIndex = marks.length - 1;
            
            marks[prevIndex].classList.add('current-match');
            marks[prevIndex].scrollIntoView({behavior: 'smooth', block: 'center'});
            
            return prevIndex + 1;
        })();
        """
        
        webView.evaluateJavaScript(jsCode) { [weak self] result, error in
            if let index = result as? Int {
                self?.currentMatchIndex = index
                self?.findPanel.updateStatus(current: index, total: self?.totalMatches ?? 0)
            }
        }
    }
    
    private func clearHighlights() {
        let jsCode = """
        (function() {
            document.querySelectorAll('.mpreview-find-highlight').forEach(el => {
                var parent = el.parentNode;
                parent.replaceChild(document.createTextNode(el.textContent), el);
                parent.normalize();
            });
        })();
        """
        webView.evaluateJavaScript(jsCode)
        totalMatches = 0
        currentMatchIndex = 0
        findPanel.updateStatus(current: 0, total: 0)
    }
    
    @objc override func performTextFinderAction(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }
        
        switch NSTextFinder.Action(rawValue: menuItem.tag) {
        case .showFindInterface:
            showFindPanel()
            
        case .hideFindInterface:
            hideFindPanel()
            
        case .nextMatch:
            findNext()
            
        case .previousMatch:
            findPrevious()
            
        case .showReplaceInterface:
            break
            
        case .replace, .replaceAll, .replaceAndFind:
            break
            
        case .setSearchString:
            getSelectedText { [weak self] text in
                if let text = text, !text.isEmpty {
                    self?.performSearch(text)
                }
            }
            
        case .selectAll, .selectAllInSelection:
            break
            
        default:
            break
        }
    }
    
    func getScrollPosition(_ completion: @escaping (CGPoint) -> Void) {
        let js = "({ x: window.scrollX, y: window.scrollY })"

        webView.evaluateJavaScript(js) { result, _ in
            if let dict = result as? [String: CGFloat],
               let x = dict["x"],
               let y = dict["y"] {
                completion(CGPoint(x: x, y: y))
            } else {
                completion(.zero)
            }
        }
    }
    
    func restoreScrollPosition(_ point: CGPoint) {
        let js = "window.scrollTo(\(point.x), \(point.y));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
