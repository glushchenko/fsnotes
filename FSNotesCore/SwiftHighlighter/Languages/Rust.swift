//
//  RustLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct RustLanguage: LanguageDefinition {
    let name = "Rust"
    let aliases: [String]? = ["rs"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "as", "async", "await", "break", "const", "continue", "crate", "dyn",
            "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
            "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
            "self", "Self", "static", "struct", "super", "trait", "true", "type",
            "unsafe", "use", "where", "while",
            // Reserved keywords
            "abstract", "become", "box", "do", "final", "macro", "override",
            "priv", "typeof", "unsized", "virtual", "yield",
            // Edition 2018+
            "try"
        ],
        "literal": ["true", "false"],
        "built_in": [
            // Primitive types
            "bool", "char", "str",
            "i8", "i16", "i32", "i64", "i128", "isize",
            "u8", "u16", "u32", "u64", "u128", "usize",
            "f32", "f64",
            // Common types
            "String", "Vec", "Box", "Option", "Result", "Some", "None", "Ok", "Err",
            "HashMap", "HashSet", "BTreeMap", "BTreeSet", "LinkedList", "VecDeque",
            "BinaryHeap", "Rc", "Arc", "Cell", "RefCell", "Cow", "Mutex", "RwLock",
            "Path", "PathBuf", "OsString", "OsStr",
            // Traits
            "Copy", "Clone", "Debug", "Display", "Default", "Drop", "Eq", "PartialEq",
            "Ord", "PartialOrd", "Hash", "Iterator", "IntoIterator", "FromIterator",
            "Extend", "From", "Into", "AsRef", "AsMut", "Deref", "DerefMut",
            "Add", "Sub", "Mul", "Div", "Rem", "Not", "BitAnd", "BitOr", "BitXor",
            "Shl", "Shr", "Index", "IndexMut", "Fn", "FnMut", "FnOnce",
            "Read", "Write", "Seek", "BufRead", "Send", "Sync", "Sized", "Unpin",
            // Macros
            "println", "print", "eprintln", "eprint", "format", "panic", "assert",
            "assert_eq", "assert_ne", "debug_assert", "debug_assert_eq", "debug_assert_ne",
            "vec", "concat", "include", "include_str", "include_bytes", "env",
            "option_env", "cfg", "line", "column", "file", "stringify", "module_path",
            "compile_error", "unimplemented", "unreachable", "todo", "matches",
            "dbg", "write", "writeln",
            // Common functions and methods
            "unwrap", "expect", "unwrap_or", "unwrap_or_else", "unwrap_or_default",
            "map", "and_then", "or_else", "filter", "collect", "iter", "into_iter",
            "iter_mut", "len", "is_empty", "push", "pop", "insert", "remove", "clear",
            "get", "get_mut", "contains", "split", "join", "trim", "to_string",
            "to_owned", "clone", "chars", "bytes", "lines", "parse", "replace",
            // std modules
            "std", "core", "alloc", "collections", "sync", "thread", "io", "fs",
            "net", "process", "time", "env", "path", "fmt", "mem", "ptr", "slice",
            "convert", "ops", "cmp", "any", "marker"
        ]
    ]
    let contains: [Mode] = [
        // Doc comments
        Mode(scope: "comment.doc", begin: "///", end: "\n", contains: []),
        Mode(scope: "comment.doc", begin: "//!", end: "\n", contains: []),
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/", contains: []),
        Mode(scope: "comment.doc", begin: "/\\*!", end: "\\*/", contains: []),
        
        // Многострочные комментарии
        Mode(scope: "comment", begin: "/\\*", end: "\\*/", contains: []),
        
        // Однострочные комментарии
        Mode(scope: "comment", begin: "//", end: "\n", contains: []),
        
        // Атрибуты
        Mode(scope: "meta", begin: "#!?\\[", end: "\\]", contains: []),
        
        // Lifetime annotations
        Mode(scope: "meta", begin: "'[a-zA-Z_][a-zA-Z0-9_]*\\b"),
        
        // Макросы
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*!"),
        
        // Определение функций
        Mode(scope: "function", begin: "\\bfn\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Определение типов, структур, энумов, трейтов
        Mode(scope: "class", begin: "\\b(?:struct|enum|trait|type|union)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Raw string literals
        Mode(scope: "string", begin: "r#+\"", end: "\"#+", contains: []),
        Mode(scope: "string", begin: "r\"", end: "\"", contains: []),
        
        // Byte string literals
        Mode(scope: "string", begin: "b\"", end: "\"", contains: []),
        Mode(scope: "string", begin: "br#+\"", end: "\"#+", contains: []),
        Mode(scope: "string", begin: "br\"", end: "\"", contains: []),
        
        // Обычные строки
        CommonModes.stringDouble,
        
        // Символьные литералы
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        
        // Byte literals
        Mode(scope: "string", begin: "b'(?:[^'\\\\]|\\\\.)+'"),
        
        // Числа
        // Binary
        Mode(scope: "number", begin: "\\b0b[01_]+(?:[ui](?:8|16|32|64|128|size))?\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0o[0-7_]+(?:[ui](?:8|16|32|64|128|size))?\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0x[0-9a-fA-F_]+(?:[ui](?:8|16|32|64|128|size))?\\b"),
        // Float with exponent
        Mode(scope: "number", begin: "\\b\\d[0-9_]*(?:\\.[0-9_]+)?[eE][+-]?[0-9_]+(?:f(?:32|64))?\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\.[0-9_]+(?:f(?:32|64))?\\b"),
        // Integer with suffix
        Mode(scope: "number", begin: "\\b\\d[0-9_]*(?:[ui](?:8|16|32|64|128|size)|f(?:32|64))\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\b"),
    ]
}
