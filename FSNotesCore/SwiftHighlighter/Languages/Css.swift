//
//  CSSLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct CSSLanguage: LanguageDefinition {
    let name = "CSS"
    let aliases: [String]? = ["css"]
    let caseInsensitive = true
    let keywords: [String: [String]]? = [
        "keyword": [
            // At-rules
            "@charset", "@import", "@namespace", "@media", "@supports", "@page",
            "@font-face", "@keyframes", "@counter-style", "@font-feature-values",
            "@property", "@layer", "@container", "@scope",
            // Media query keywords
            "and", "not", "only", "or",
            // Important
            "!important",
            // Logical operators
            "from", "to"
        ],
        "literal": [
            // Color keywords
            "transparent", "currentColor", "inherit", "initial", "unset", "revert",
            // Named colors (common ones)
            "black", "white", "red", "green", "blue", "yellow", "orange", "purple",
            "pink", "brown", "gray", "grey", "cyan", "magenta", "lime", "navy",
            "teal", "aqua", "maroon", "olive", "silver", "fuchsia",
            // System colors
            "ActiveBorder", "ActiveCaption", "AppWorkspace", "Background", "ButtonFace",
            "ButtonHighlight", "ButtonShadow", "ButtonText", "CaptionText", "GrayText",
            "Highlight", "HighlightText", "InactiveBorder", "InactiveCaption",
            "InactiveCaptionText", "InfoBackground", "InfoText", "Menu", "MenuText",
            "Scrollbar", "ThreeDDarkShadow", "ThreeDFace", "ThreeDHighlight",
            "ThreeDLightShadow", "ThreeDShadow", "Window", "WindowFrame", "WindowText"
        ],
        "built_in": [
            // Properties - Layout
            "display", "position", "top", "right", "bottom", "left", "float", "clear",
            "z-index", "overflow", "overflow-x", "overflow-y", "overflow-wrap",
            "clip", "clip-path", "visibility", "isolation",
            // Properties - Box Model
            "width", "height", "min-width", "max-width", "min-height", "max-height",
            "margin", "margin-top", "margin-right", "margin-bottom", "margin-left",
            "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
            "border", "border-width", "border-style", "border-color",
            "border-top", "border-right", "border-bottom", "border-left",
            "border-top-width", "border-top-style", "border-top-color",
            "border-right-width", "border-right-style", "border-right-color",
            "border-bottom-width", "border-bottom-style", "border-bottom-color",
            "border-left-width", "border-left-style", "border-left-color",
            "border-radius", "border-top-left-radius", "border-top-right-radius",
            "border-bottom-right-radius", "border-bottom-left-radius",
            "border-image", "border-image-source", "border-image-slice",
            "border-image-width", "border-image-repeat", "border-image-outset",
            "box-sizing", "box-shadow", "outline", "outline-width", "outline-style",
            "outline-color", "outline-offset",
            // Properties - Background
            "background", "background-color", "background-image", "background-repeat",
            "background-position", "background-size", "background-attachment",
            "background-origin", "background-clip", "background-blend-mode",
            // Properties - Typography
            "color", "font", "font-family", "font-size", "font-weight", "font-style",
            "font-variant", "font-stretch", "font-size-adjust", "font-synthesis",
            "font-kerning", "font-variant-ligatures", "font-variant-position",
            "font-variant-caps", "font-variant-numeric", "font-variant-alternates",
            "font-variant-east-asian", "font-feature-settings", "font-variation-settings",
            "line-height", "letter-spacing", "word-spacing", "text-align",
            "text-align-last", "text-decoration", "text-decoration-line",
            "text-decoration-color", "text-decoration-style", "text-decoration-thickness",
            "text-underline-position", "text-underline-offset", "text-indent",
            "text-transform", "text-shadow", "text-overflow", "text-wrap",
            "white-space", "word-break", "word-wrap", "hyphens", "tab-size",
            "direction", "unicode-bidi", "writing-mode", "text-orientation",
            "vertical-align",
            // Properties - Flexbox
            "flex", "flex-direction", "flex-wrap", "flex-flow", "flex-grow",
            "flex-shrink", "flex-basis", "justify-content", "align-items",
            "align-self", "align-content", "order", "gap", "row-gap", "column-gap",
            // Properties - Grid
            "grid", "grid-template", "grid-template-columns", "grid-template-rows",
            "grid-template-areas", "grid-auto-columns", "grid-auto-rows",
            "grid-auto-flow", "grid-column", "grid-row", "grid-area",
            "grid-column-start", "grid-column-end", "grid-row-start", "grid-row-end",
            "justify-items", "justify-self", "place-items", "place-self", "place-content",
            // Properties - Transform & Animation
            "transform", "transform-origin", "transform-style", "transform-box",
            "perspective", "perspective-origin", "backface-visibility",
            "transition", "transition-property", "transition-duration",
            "transition-timing-function", "transition-delay",
            "animation", "animation-name", "animation-duration", "animation-timing-function",
            "animation-delay", "animation-iteration-count", "animation-direction",
            "animation-fill-mode", "animation-play-state", "animation-timeline",
            "rotate", "scale", "translate",
            // Properties - Filters & Effects
            "filter", "backdrop-filter", "opacity", "mix-blend-mode",
            "mask", "mask-image", "mask-mode", "mask-repeat", "mask-position",
            "mask-clip", "mask-origin", "mask-size", "mask-composite",
            // Properties - Lists & Counters
            "list-style", "list-style-type", "list-style-position", "list-style-image",
            "counter-reset", "counter-increment", "counter-set",
            // Properties - Tables
            "table-layout", "border-collapse", "border-spacing", "caption-side",
            "empty-cells",
            // Properties - Columns
            "columns", "column-width", "column-count", "column-gap", "column-rule",
            "column-rule-width", "column-rule-style", "column-rule-color",
            "column-span", "column-fill", "break-before", "break-after", "break-inside",
            // Properties - User Interface
            "cursor", "pointer-events", "resize", "user-select", "caret-color",
            "accent-color", "appearance", "outline", "scroll-behavior",
            "scroll-margin", "scroll-padding", "scroll-snap-type", "scroll-snap-align",
            "scroll-snap-stop", "overscroll-behavior", "touch-action",
            // Properties - Content
            "content", "quotes", "content-visibility", "contain",
            // Properties - Printing
            "page-break-before", "page-break-after", "page-break-inside",
            "orphans", "widows",
            // Properties - Other
            "all", "will-change", "object-fit", "object-position", "image-rendering",
            "image-orientation", "aspect-ratio", "inset", "inset-block", "inset-inline",
            // Property values - Display
            "block", "inline", "inline-block", "flex", "inline-flex", "grid",
            "inline-grid", "table", "table-row", "table-cell", "list-item",
            "none", "contents", "flow-root",
            // Property values - Position
            "static", "relative", "absolute", "fixed", "sticky",
            // Property values - Float
            "left", "right", "none",
            // Property values - Text align
            "center", "justify", "start", "end",
            // Property values - Border style
            "solid", "dashed", "dotted", "double", "groove", "ridge", "inset",
            "outset", "hidden",
            // Property values - Font weight
            "normal", "bold", "bolder", "lighter",
            // Property values - Font style
            "italic", "oblique",
            // Property values - Text decoration
            "underline", "overline", "line-through",
            // Property values - Text transform
            "uppercase", "lowercase", "capitalize",
            // Property values - White space
            "nowrap", "pre", "pre-wrap", "pre-line",
            // Property values - Overflow
            "visible", "hidden", "scroll", "auto", "clip",
            // Property values - Cursor
            "pointer", "default", "crosshair", "move", "text", "wait", "help",
            "grab", "grabbing", "zoom-in", "zoom-out", "not-allowed", "progress",
            // Property values - Repeat
            "repeat", "repeat-x", "repeat-y", "no-repeat", "space", "round",
            // Property values - Size
            "auto", "contain", "cover",
            // Property values - Flex/Grid
            "row", "column", "wrap", "nowrap", "flex-start", "flex-end", "space-between",
            "space-around", "space-evenly", "stretch", "baseline",
            // Units
            "px", "em", "rem", "vh", "vw", "vmin", "vmax", "%", "cm", "mm", "in",
            "pt", "pc", "ch", "ex", "fr", "deg", "rad", "grad", "turn", "s", "ms",
            // Functions
            "url", "rgb", "rgba", "hsl", "hsla", "calc", "var", "attr",
            "linear-gradient", "radial-gradient", "conic-gradient",
            "repeating-linear-gradient", "repeating-radial-gradient",
            "repeating-conic-gradient", "min", "max", "clamp", "minmax",
            "fit-content", "blur", "brightness", "contrast", "drop-shadow",
            "grayscale", "hue-rotate", "invert", "opacity", "saturate", "sepia",
            "rotate", "scale", "scaleX", "scaleY", "scaleZ", "scale3d",
            "skew", "skewX", "skewY", "translate", "translateX", "translateY",
            "translateZ", "translate3d", "matrix", "matrix3d", "perspective",
            "cubic-bezier", "steps", "counters", "symbols", "path", "polygon",
            "circle", "ellipse", "inset"
        ]
    ]
    let contains: [Mode] = [
        // Multi-line comments
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        
        // Single-line comments (non-standard but used in preprocessors)
        Mode(scope: "comment", begin: "//", end: "\n"),
        
        // At-rules
        Mode(scope: "meta", begin: "@[a-z-]+"),
        
        // Selectors - IDs
        Mode(scope: "meta", begin: "#[a-zA-Z][a-zA-Z0-9_-]*"),
        
        // Selectors - Classes
        Mode(scope: "meta", begin: "\\.[a-zA-Z][a-zA-Z0-9_-]*"),
        
        // Selectors - Pseudo-classes
        Mode(scope: "meta", begin: ":[a-zA-Z][a-zA-Z0-9_-]*(?:\\([^)]*\\))?"),
        
        // Selectors - Pseudo-elements
        Mode(scope: "meta", begin: "::[a-zA-Z][a-zA-Z0-9_-]*"),
        
        // Selectors - Attribute selectors
        Mode(scope: "meta", begin: "\\[", end: "\\]"),
        
        // Property names
        Mode(scope: "keyword", begin: "\\b[a-z-]+(?=\\s*:)"),
        
        // Strings with double quotes
        CommonModes.stringDouble,
        
        // Strings with single quotes
        CommonModes.stringSingle,
        
        // URLs
        Mode(scope: "string", begin: "url\\(", end: "\\)"),
        
        // Important
        Mode(scope: "keyword", begin: "!important\\b"),
        
        // Functions
        Mode(scope: "function", begin: "\\b[a-z-]+\\("),
        
        // Variables (CSS custom properties)
        Mode(scope: "meta", begin: "--[a-zA-Z][a-zA-Z0-9_-]*"),
        Mode(scope: "function", begin: "var\\("),
        
        // Colors - Hex
        Mode(scope: "number", begin: "#[0-9a-fA-F]{3,8}\\b"),
        
        // Colors - RGB/RGBA
        Mode(scope: "function", begin: "rgba?\\("),
        
        // Colors - HSL/HSLA
        Mode(scope: "function", begin: "hsla?\\("),
        
        // Numbers with units
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*(?:px|em|rem|%|vh|vw|vmin|vmax|cm|mm|in|pt|pc|ch|ex|fr|deg|rad|grad|turn|s|ms)\\b"),
        
        // Plain numbers
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*\\b"),
    ]
}
