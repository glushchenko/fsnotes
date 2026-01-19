//
//  HTMLLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct HTMLLanguage: LanguageDefinition {
    let name = "HTML"
    let aliases: [String]? = ["html", "htm", "xhtml"]
    let caseInsensitive = true
    let keywords: [String: [String]]? = [
        "keyword": [],
        "literal": [],
        "built_in": [
            // Document structure
            "html", "head", "title", "base", "link", "meta", "style", "body",
            // Sections
            "header", "nav", "main", "section", "article", "aside", "footer",
            "h1", "h2", "h3", "h4", "h5", "h6", "hgroup", "address",
            // Grouping content
            "p", "hr", "pre", "blockquote", "ol", "ul", "li", "dl", "dt", "dd",
            "figure", "figcaption", "div",
            // Text-level semantics
            "a", "em", "strong", "small", "s", "cite", "q", "dfn", "abbr", "data",
            "time", "code", "var", "samp", "kbd", "sub", "sup", "i", "b", "u",
            "mark", "ruby", "rt", "rp", "bdi", "bdo", "span", "br", "wbr",
            // Edits
            "ins", "del",
            // Embedded content
            "img", "iframe", "embed", "object", "param", "video", "audio", "source",
            "track", "canvas", "map", "area", "svg", "math",
            // Tabular data
            "table", "caption", "colgroup", "col", "tbody", "thead", "tfoot", "tr",
            "td", "th",
            // Forms
            "form", "label", "input", "button", "select", "datalist", "optgroup",
            "option", "textarea", "output", "progress", "meter", "fieldset", "legend",
            // Interactive elements
            "details", "summary", "dialog", "menu",
            // Scripting
            "script", "noscript", "template", "slot", "canvas",
            // Web Components
            "template", "slot",
            // Obsolete/deprecated (but still used)
            "center", "font", "strike", "big", "tt", "frame", "frameset", "noframes",
            "acronym", "applet", "basefont", "dir", "isindex", "listing", "marquee",
            "plaintext", "xmp", "nextid", "rb", "rtc",
            // HTML5 new elements
            "article", "aside", "bdi", "command", "details", "summary", "figure",
            "figcaption", "footer", "header", "hgroup", "mark", "meter", "nav",
            "progress", "ruby", "rt", "rp", "section", "time", "wbr", "datalist",
            "keygen", "output", "canvas", "audio", "video", "source", "embed",
            "track", "main", "picture",
            // Attributes (common)
            "class", "id", "style", "title", "lang", "dir", "hidden", "tabindex",
            "accesskey", "contenteditable", "contextmenu", "draggable", "dropzone",
            "spellcheck", "translate", "role", "aria-label", "aria-labelledby",
            "aria-describedby", "aria-hidden", "data-",
            // Form attributes
            "action", "method", "enctype", "accept-charset", "novalidate",
            "autocomplete", "autofocus", "disabled", "readonly", "required",
            "placeholder", "pattern", "min", "max", "step", "minlength", "maxlength",
            "size", "multiple", "checked", "selected", "value", "name", "type",
            "for", "form",
            // Link/script attributes
            "href", "src", "alt", "crossorigin", "rel", "media", "hreflang",
            "type", "sizes", "async", "defer", "charset", "integrity",
            // Image/media attributes
            "width", "height", "loading", "decoding", "srcset", "sizes", "poster",
            "preload", "autoplay", "loop", "muted", "controls", "playsinline",
            // Table attributes
            "colspan", "rowspan", "headers", "scope",
            // Meta attributes
            "content", "http-equiv", "charset", "name",
            // Global event attributes
            "onclick", "ondblclick", "onmousedown", "onmouseup", "onmouseover",
            "onmousemove", "onmouseout", "onkeypress", "onkeydown", "onkeyup",
            "onfocus", "onblur", "onchange", "onsubmit", "onload", "onunload",
            "onerror", "onresize", "onscroll", "onwheel", "oncopy", "oncut",
            "onpaste", "ondrag", "ondragstart", "ondragend", "ondragover",
            "ondragenter", "ondragleave", "ondrop", "ontouchstart", "ontouchmove",
            "ontouchend", "ontouchcancel"
        ]
    ]
    let contains: [Mode] = [
        // HTML comments
        Mode(scope: "comment", begin: "<!--", end: "-->"),
        
        // DOCTYPE declaration
        Mode(scope: "meta", begin: "<!DOCTYPE", end: ">"),
        
        // XML declaration
        Mode(scope: "meta", begin: "<\\?xml", end: "\\?>"),
        
        // CDATA sections
        Mode(scope: "string", begin: "<!\\[CDATA\\[", end: "\\]\\]>"),
        
        // Processing instructions
        Mode(scope: "meta", begin: "<\\?", end: "\\?>"),
        
        // Opening tags with attributes
        Mode(scope: "keyword", begin: "<[a-zA-Z][a-zA-Z0-9-]*"),
        
        // Closing tags
        Mode(scope: "keyword", begin: "</[a-zA-Z][a-zA-Z0-9-]*>"),
        
        // Self-closing tags
        Mode(scope: "keyword", begin: "/>"),
        
        // Attribute names
        Mode(scope: "meta", begin: "\\b[a-zA-Z][a-zA-Z0-9-]*(?==)"),
        
        // Attribute values with double quotes
        Mode(scope: "string", begin: "=\"", end: "\""),
        
        // Attribute values with single quotes
        Mode(scope: "string", begin: "='", end: "'"),
        
        // Entity references
        Mode(scope: "string", begin: "&[a-zA-Z]+;"),
        Mode(scope: "string", begin: "&#[0-9]+;"),
        Mode(scope: "string", begin: "&#x[0-9a-fA-F]+;"),
        
        // Tag closing bracket
        Mode(scope: "keyword", begin: ">"),
    ]
}
