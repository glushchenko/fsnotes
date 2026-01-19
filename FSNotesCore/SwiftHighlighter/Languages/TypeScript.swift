//
//  TypeScriptLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct TypeScriptLanguage: LanguageDefinition {
    let name = "TypeScript"
    let aliases: [String]? = ["typescript", "ts", "tsx"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // JavaScript keywords
            "as", "async", "await", "break", "case", "catch", "class", "const",
            "continue", "debugger", "default", "delete", "do", "else", "enum",
            "export", "extends", "false", "finally", "for", "from", "function",
            "get", "if", "import", "in", "instanceof", "let", "new", "null",
            "of", "return", "set", "static", "super", "switch", "this", "throw",
            "true", "try", "typeof", "var", "void", "while", "with", "yield",
            // TypeScript specific
            "abstract", "as", "asserts", "any", "boolean", "constructor", "declare",
            "get", "infer", "interface", "is", "keyof", "module", "namespace",
            "never", "readonly", "require", "number", "object", "set", "string",
            "symbol", "type", "undefined", "unique", "unknown", "from", "global",
            "bigint", "of", "implements", "private", "protected", "public",
            // Modifiers
            "abstract", "async", "const", "declare", "export", "private", "protected",
            "public", "readonly", "static", "override"
        ],
        "literal": ["true", "false", "null", "undefined", "NaN", "Infinity"],
        "built_in": [
            // Primitive types
            "any", "boolean", "number", "string", "symbol", "void", "undefined",
            "null", "never", "unknown", "bigint", "object",
            // Built-in types
            "Array", "ArrayBuffer", "AsyncIterable", "AsyncIterableIterator",
            "AsyncIterator", "Atomics", "BigInt", "BigInt64Array", "BigUint64Array",
            "Boolean", "DataView", "Date", "Error", "EvalError", "Float32Array",
            "Float64Array", "Function", "Generator", "GeneratorFunction", "Infinity",
            "Int8Array", "Int16Array", "Int32Array", "Intl", "InternalError",
            "Iterable", "IterableIterator", "Iterator", "JSON", "Map", "Math",
            "NaN", "Number", "Object", "Promise", "Proxy", "RangeError",
            "ReferenceError", "Reflect", "RegExp", "Set", "SharedArrayBuffer",
            "String", "Symbol", "SyntaxError", "TypeError", "Uint8Array",
            "Uint8ClampedArray", "Uint16Array", "Uint32Array", "URIError",
            "WeakMap", "WeakSet", "WebAssembly",
            // Utility types
            "Partial", "Required", "Readonly", "Record", "Pick", "Omit", "Exclude",
            "Extract", "NonNullable", "Parameters", "ConstructorParameters",
            "ReturnType", "InstanceType", "ThisParameterType", "OmitThisParameter",
            "ThisType", "Uppercase", "Lowercase", "Capitalize", "Uncapitalize",
            "Awaited",
            // Global functions
            "eval", "isFinite", "isNaN", "parseFloat", "parseInt", "decodeURI",
            "decodeURIComponent", "encodeURI", "encodeURIComponent", "escape",
            "unescape",
            // Console
            "console", "log", "warn", "error", "info", "debug", "trace", "assert",
            "clear", "count", "countReset", "dir", "dirxml", "group", "groupCollapsed",
            "groupEnd", "table", "time", "timeEnd", "timeLog", "profile", "profileEnd",
            // Common methods
            "toString", "toLocaleString", "valueOf", "hasOwnProperty",
            "isPrototypeOf", "propertyIsEnumerable", "constructor",
            // Array methods
            "concat", "copyWithin", "entries", "every", "fill", "filter", "find",
            "findIndex", "flat", "flatMap", "forEach", "from", "includes", "indexOf",
            "isArray", "join", "keys", "lastIndexOf", "map", "of", "pop", "push",
            "reduce", "reduceRight", "reverse", "shift", "slice", "some", "sort",
            "splice", "toLocaleString", "toString", "unshift", "values",
            // String methods
            "charAt", "charCodeAt", "codePointAt", "concat", "endsWith", "includes",
            "indexOf", "lastIndexOf", "localeCompare", "match", "matchAll", "normalize",
            "padEnd", "padStart", "repeat", "replace", "replaceAll", "search", "slice",
            "split", "startsWith", "substring", "toLowerCase", "toLocaleLowerCase",
            "toUpperCase", "toLocaleUpperCase", "trim", "trimEnd", "trimStart",
            // Object methods
            "assign", "create", "defineProperties", "defineProperty", "entries",
            "freeze", "fromEntries", "getOwnPropertyDescriptor",
            "getOwnPropertyDescriptors", "getOwnPropertyNames",
            "getOwnPropertySymbols", "getPrototypeOf", "is", "isExtensible",
            "isFrozen", "isSealed", "keys", "preventExtensions", "seal",
            "setPrototypeOf", "values",
            // Promise methods
            "all", "allSettled", "any", "race", "reject", "resolve", "then",
            "catch", "finally",
            // Map/Set methods
            "clear", "delete", "entries", "forEach", "get", "has", "keys", "set",
            "size", "values",
            // Math methods
            "abs", "acos", "acosh", "asin", "asinh", "atan", "atan2", "atanh",
            "cbrt", "ceil", "clz32", "cos", "cosh", "exp", "expm1", "floor",
            "fround", "hypot", "imul", "log", "log10", "log1p", "log2", "max",
            "min", "pow", "random", "round", "sign", "sin", "sinh", "sqrt", "tan",
            "tanh", "trunc", "E", "LN2", "LN10", "LOG2E", "LOG10E", "PI",
            "SQRT1_2", "SQRT2",
            // Number methods
            "isFinite", "isInteger", "isNaN", "isSafeInteger", "parseFloat",
            "parseInt", "toExponential", "toFixed", "toPrecision",
            // JSON methods
            "parse", "stringify",
            // Module/namespace
            "require", "module", "exports", "__dirname", "__filename", "global",
            // TypeScript globals
            "NodeJS", "RequestInit", "Response", "Request", "Headers", "FormData",
            "Blob", "File", "ReadableStream", "WritableStream", "TextEncoder",
            "TextDecoder", "URL", "URLSearchParams", "Event", "EventTarget",
            "AbortController", "AbortSignal",
            // React (for TSX)
            "React", "Component", "PureComponent", "Fragment", "createElement",
            "cloneElement", "createContext", "forwardRef", "lazy", "memo",
            "startTransition", "useCallback", "useContext", "useDebugValue",
            "useDeferredValue", "useEffect", "useId", "useImperativeHandle",
            "useInsertionEffect", "useLayoutEffect", "useMemo", "useReducer",
            "useRef", "useState", "useSyncExternalStore", "useTransition",
            "JSX", "ReactElement", "ReactNode", "FC", "PropsWithChildren"
        ]
    ]
    let contains: [Mode] = [
        // JSDoc comments
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/"),
        
        // Multi-line comments
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        
        // Single-line comments
        Mode(scope: "comment", begin: "//", end: "\n"),
        
        // Type annotations
        Mode(scope: "meta", begin: ":\\s*[a-zA-Z_][a-zA-Z0-9_<>\\[\\]|&,\\s]*"),
        
        // Generic type parameters
        Mode(scope: "meta", begin: "<[a-zA-Z_][a-zA-Z0-9_<>\\[\\]|&,\\s]*>"),
        
        // Type assertions
        Mode(scope: "meta", begin: "\\bas\\s+[a-zA-Z_][a-zA-Z0-9_<>\\[\\]|&]*"),
        Mode(scope: "meta", begin: "<[a-zA-Z_][a-zA-Z0-9_<>\\[\\]|&]*>(?=\\s*[a-zA-Z_({['\"])"),
        
        // Interface/Type definitions
        Mode(scope: "class", begin: "\\b(?:interface|type|enum|namespace|module|declare)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Class definitions
        Mode(scope: "class", begin: "\\bclass\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Function definitions
        Mode(scope: "function", begin: "\\bfunction\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Arrow functions
        Mode(scope: "function", begin: "\\([^)]*\\)\\s*=>"),
        Mode(scope: "function", begin: "[a-zA-Z_][a-zA-Z0-9_]*\\s*=>"),
        
        // Method definitions
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\s*\\("),
        
        // Decorators
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*"),
        
        // Template literals
        Mode(scope: "string", begin: "`", end: "`"),
        
        // Regular strings
        CommonModes.stringDouble,
        CommonModes.stringSingle,
        
        // Regular expressions
        Mode(scope: "string", begin: "/(?![*/])", end: "/[gimsuvy]*"),
        
        // JSX/TSX tags
        Mode(scope: "keyword", begin: "</?[A-Z][a-zA-Z0-9]*"),
        Mode(scope: "keyword", begin: "</?[a-z][a-zA-Z0-9-]*"),
        
        // Numbers
        // Binary
        Mode(scope: "number", begin: "\\b0[bB][01_]+n?\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[oO][0-7_]+n?\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F_]+n?\\b"),
        // BigInt
        Mode(scope: "number", begin: "\\b\\d+n\\b"),
        // Float with exponent
        Mode(scope: "number", begin: "\\b\\d+(?:\\.\\d+)?[eE][+-]?\\d+\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
