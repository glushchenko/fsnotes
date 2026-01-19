//
//  GoLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct GoLanguage: LanguageDefinition {
    let name = "Go"
    let aliases: [String]? = ["go", "golang"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "break", "case", "chan", "const", "continue", "default", "defer",
            "else", "fallthrough", "for", "func", "go", "goto", "if", "import",
            "interface", "map", "package", "range", "return", "select", "struct",
            "switch", "type", "var"
        ],
        "literal": ["true", "false", "nil", "iota"],
        "built_in": [
            // Базовые типы
            "bool", "byte", "rune", "string", "error",
            "int", "int8", "int16", "int32", "int64",
            "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
            "float32", "float64", "complex64", "complex128",
            // Встроенные функции
            "append", "cap", "close", "complex", "copy", "delete", "imag",
            "len", "make", "new", "panic", "print", "println", "real", "recover",
            // Типы и интерфейсы
            "any", "comparable",
            // Пакет fmt
            "Print", "Printf", "Println", "Sprint", "Sprintf", "Sprintln",
            "Fprint", "Fprintf", "Fprintln", "Scan", "Scanf", "Scanln",
            "Fscan", "Fscanf", "Fscanln", "Sscan", "Sscanf", "Sscanln",
            "Errorf",
            // Пакет errors
            "New", "Is", "As", "Unwrap",
            // Пакет io
            "Reader", "Writer", "ReadWriter", "ReadCloser", "WriteCloser",
            "ReadWriteCloser", "Copy", "ReadAll", "ReadFull", "WriteString",
            "EOF", "Closer",
            // Пакет os
            "File", "Open", "Create", "OpenFile", "Stdin", "Stdout", "Stderr",
            "Args", "Getenv", "Setenv", "Exit", "Remove", "RemoveAll", "Mkdir",
            "MkdirAll", "Chdir", "Getwd",
            // Пакет time
            "Time", "Duration", "Now", "Since", "Until", "Sleep", "After",
            "Ticker", "Timer", "Parse", "ParseDuration",
            "Second", "Minute", "Hour", "Millisecond", "Microsecond", "Nanosecond",
            // Пакет strings
            "Contains", "ContainsAny", "Count", "HasPrefix", "HasSuffix",
            "Index", "Join", "Replace", "Split", "ToLower", "ToUpper", "Trim",
            "TrimSpace", "Builder",
            // Пакет strconv
            "Atoi", "Itoa", "ParseBool", "ParseFloat", "ParseInt", "ParseUint",
            "FormatBool", "FormatFloat", "FormatInt", "FormatUint",
            // Пакет bytes
            "Buffer", "Equal", "Compare",
            // Пакет sync
            "Mutex", "RWMutex", "WaitGroup", "Once", "Cond", "Pool", "Map",
            "Lock", "Unlock", "RLock", "RUnlock", "Wait", "Done", "Add",
            // Пакет context
            "Context", "Background", "TODO", "WithCancel", "WithDeadline",
            "WithTimeout", "WithValue",
            // Пакет http
            "Request", "Response", "Client", "Server", "Handler", "HandlerFunc",
            "Get", "Post", "Head", "ListenAndServe", "Handle", "HandleFunc",
            "StatusOK", "StatusNotFound", "StatusInternalServerError",
            // Пакет json
            "Marshal", "Unmarshal", "Encoder", "Decoder", "RawMessage",
            // Пакет regexp
            "Regexp", "Compile", "MustCompile", "Match", "MatchString",
            "FindString", "FindAllString",
            // Пакет sort
            "Sort", "Slice", "Strings", "Ints", "Float64s", "Search",
            // Пакет math
            "Abs", "Ceil", "Floor", "Max", "Min", "Pow", "Sqrt", "Round",
            "Sin", "Cos", "Tan", "Pi", "E", "Inf", "NaN", "IsNaN", "IsInf"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        Mode(scope: "comment", begin: "//", end: "\n"),
        Mode(scope: "function", begin: "\\bfunc\\s+(?:\\([^)]*\\)\\s+)?([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        Mode(scope: "class", begin: "\\btype\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "\\b(?:struct|interface)\\b"),
        
        // Raw string literals (backticks)
        Mode(scope: "string", begin: "`", end: "`"),
        Mode(scope: "string", begin: "\"", end: "\""),
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+(?:\\.[0-9a-fA-F]+)?[pP]?[+-]?\\d*\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[oO][0-7]+\\b"),
        // Binary
        Mode(scope: "number", begin: "\\b0[bB][01]+\\b"),
        // Float with exponent
        Mode(scope: "number", begin: "\\b\\d+(?:\\.\\d+)?[eE][+-]?\\d+[i]?\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[i]?\\b"),
        // Integer with underscores
        Mode(scope: "number", begin: "\\b\\d+(?:_\\d+)*[i]?\\b"),
        // Imaginary numbers
        Mode(scope: "number", begin: "\\b\\d+i\\b"),
    ]
}
