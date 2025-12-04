//
//  CLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct CLanguage: LanguageDefinition {
    let name = "C"
    let aliases: [String]? = ["c", "h"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "auto", "break", "case", "char", "const", "continue", "default", "do",
            "double", "else", "enum", "extern", "float", "for", "goto", "if",
            "inline", "int", "long", "register", "restrict", "return", "short",
            "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
            "unsigned", "void", "volatile", "while",
            // C99
            "_Bool", "_Complex", "_Imaginary",
            // C11
            "_Alignas", "_Alignof", "_Atomic", "_Generic", "_Noreturn",
            "_Static_assert", "_Thread_local"
        ],
        "literal": ["true", "false", "NULL"],
        "built_in": [
            // stdio.h
            "printf", "scanf", "fprintf", "fscanf", "sprintf", "sscanf",
            "fopen", "fclose", "fread", "fwrite", "fgets", "fputs", "fgetc", "fputc",
            "getchar", "putchar", "puts", "gets", "fseek", "ftell", "rewind", "feof", "ferror",
            // stdlib.h
            "malloc", "calloc", "realloc", "free", "exit", "abort", "atexit",
            "atoi", "atof", "atol", "strtol", "strtod", "rand", "srand",
            "abs", "labs", "div", "ldiv", "qsort", "bsearch",
            // string.h
            "strlen", "strcpy", "strncpy", "strcat", "strncat", "strcmp", "strncmp",
            "strchr", "strrchr", "strstr", "strtok", "memcpy", "memmove", "memset",
            "memcmp", "memchr",
            // math.h
            "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
            "sinh", "cosh", "tanh", "exp", "log", "log10", "pow", "sqrt",
            "ceil", "floor", "fabs", "fmod",
            // time.h
            "time", "clock", "difftime", "mktime", "strftime", "gmtime", "localtime",
            // ctype.h
            "isalnum", "isalpha", "isdigit", "islower", "isupper", "isspace",
            "toupper", "tolower",
            // assert.h
            "assert",
            // Типы
            "size_t", "ptrdiff_t", "wchar_t", "FILE", "time_t", "clock_t"
        ]
    ]
    let contains: [Mode] = [
        // Препроцессорные директивы
        Mode(scope: "meta", begin: "^\\s*#\\s*(?:include|define|undef|if|ifdef|ifndef|else|elif|endif|error|pragma|line)\\b.*$"),
        
        // Однострочные комментарии (C99)
        Mode(scope: "comment", begin: "//", end: "\n", contains: []),
        
        // Многострочные комментарии
        Mode(scope: "comment", begin: "/\\*", end: "\\*/", contains: []),
        
        // Определение функций
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\s*(?=\\()"),
        
        // Строки
        CommonModes.stringDouble,
        
        // Символьные литералы
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        
        // Числа
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+[uUlL]*\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[0-7]+[uUlL]*\\b"),
        // Float/Double
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[fFlL]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[eE][+-]?\\d+[fFlL]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[eE][+-]?\\d+[fFlL]?\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+[uUlL]*\\b"),
    ]
}
