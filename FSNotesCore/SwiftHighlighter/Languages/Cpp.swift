//
//  CPlusPlusLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct CppLanguage: LanguageDefinition {
    let name = "C++"
    let aliases: [String]? = ["cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // C keywords
            "auto", "break", "case", "char", "const", "continue", "default", "do",
            "double", "else", "enum", "extern", "float", "for", "goto", "if",
            "inline", "int", "long", "register", "restrict", "return", "short",
            "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
            "unsigned", "void", "volatile", "while",
            // C++ keywords
            "alignas", "alignof", "and", "and_eq", "asm", "bitand", "bitor",
            "bool", "catch", "class", "compl", "concept", "const_cast", "consteval",
            "constexpr", "constinit", "co_await", "co_return", "co_yield",
            "decltype", "delete", "dynamic_cast", "explicit", "export", "false",
            "friend", "mutable", "namespace", "new", "noexcept", "not", "not_eq",
            "nullptr", "operator", "or", "or_eq", "private", "protected", "public",
            "reinterpret_cast", "requires", "static_assert", "static_cast",
            "template", "this", "thread_local", "throw", "true", "try", "typeid",
            "typename", "using", "virtual", "wchar_t", "xor", "xor_eq"
        ],
        "literal": ["true", "false", "nullptr", "NULL"],
        "built_in": [
            // STL containers
            "std", "string", "wstring", "vector", "list", "deque", "set", "multiset",
            "map", "multimap", "unordered_set", "unordered_multiset", "unordered_map",
            "unordered_multimap", "stack", "queue", "priority_queue", "array",
            "bitset", "valarray",
            // Smart pointers
            "unique_ptr", "shared_ptr", "weak_ptr", "auto_ptr",
            // Streams
            "iostream", "istream", "ostream", "fstream", "ifstream", "ofstream",
            "stringstream", "istringstream", "ostringstream",
            "cin", "cout", "cerr", "clog", "wcin", "wcout", "wcerr", "wclog",
            // Algorithms
            "sort", "find", "find_if", "count", "count_if", "transform", "copy",
            "remove", "remove_if", "replace", "replace_if", "fill", "reverse",
            "rotate", "unique", "lower_bound", "upper_bound", "binary_search",
            "max", "min", "swap", "accumulate", "for_each",
            // Iterators
            "iterator", "const_iterator", "reverse_iterator", "const_reverse_iterator",
            "begin", "end", "rbegin", "rend", "cbegin", "cend", "crbegin", "crend",
            // Utilities
            "pair", "make_pair", "tuple", "make_tuple", "optional", "variant", "any",
            "move", "forward", "declval",
            // Memory
            "allocator", "make_unique", "make_shared",
            // Numeric types
            "int8_t", "int16_t", "int32_t", "int64_t",
            "uint8_t", "uint16_t", "uint32_t", "uint64_t",
            "size_t", "ptrdiff_t", "nullptr_t",
            // C standard library
            "printf", "scanf", "malloc", "calloc", "realloc", "free",
            "strlen", "strcpy", "strcmp", "memcpy", "memset",
            // Exception types
            "exception", "runtime_error", "logic_error", "out_of_range",
            "invalid_argument", "bad_alloc", "bad_cast", "bad_typeid"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "meta", begin: "^\\s*#\\s*(?:include|define|undef|if|ifdef|ifndef|else|elif|endif|error|pragma|line|warning)\\b.*$"),
        
        Mode(scope: "comment", begin: "//", end: "\n"),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        
        Mode(scope: "meta", begin: "template\\s*<", end: ">"),
        
        Mode(scope: "class", begin: "\\b(?:class|struct)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "\\bnamespace\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\s*(?=\\()"),
        
        // Raw string literals (C++11)
        Mode(scope: "string", begin: "R\"\\(", end: "\\)\""),
        
        
        CommonModes.stringDouble,
        
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        Mode(scope: "string", begin: "L'(?:[^'\\\\]|\\\\.)+'"),  // Wide char
        Mode(scope: "string", begin: "u'(?:[^'\\\\]|\\\\.)+'"),  // UTF-16
        Mode(scope: "string", begin: "U'(?:[^'\\\\]|\\\\.)+'"),  // UTF-32
        
        // String literals with prefixes
        Mode(scope: "string", begin: "L\"(?:[^\"\\\\]|\\\\.)*\""),  // Wide string
        Mode(scope: "string", begin: "u8\"(?:[^\"\\\\]|\\\\.)*\""), // UTF-8
        Mode(scope: "string", begin: "u\"(?:[^\"\\\\]|\\\\.)*\""),  // UTF-16
        Mode(scope: "string", begin: "U\"(?:[^\"\\\\]|\\\\.)*\""),  // UTF-32
        
        // Числа
        // Binary (C++14)
        Mode(scope: "number", begin: "\\b0[bB][01]+[uUlL]*\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+[uUlL]*\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[0-7]+[uUlL]*\\b"),
        // Float/Double with suffixes
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[fFlL]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[eE][+-]?\\d+[fFlL]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[eE][+-]?\\d+[fFlL]?\\b"),
        // Integer with digit separators (C++14)
        Mode(scope: "number", begin: "\\b\\d+(?:'\\d+)*[uUlL]*\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+[uUlL]*\\b"),
    ]
}
