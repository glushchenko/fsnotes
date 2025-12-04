//
//  PythonLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct PythonLanguage: LanguageDefinition {
    let name = "Python"
    let aliases: [String]? = ["py", "gyp", "ipython"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "and", "as", "assert", "async", "await", "break", "case", "class", "continue",
            "def", "del", "elif", "else", "except", "finally", "for", "from", "global",
            "if", "import", "in", "is", "lambda", "match", "nonlocal", "not", "or",
            "pass", "raise", "return", "try", "while", "with", "yield"
        ],
        "literal": ["True", "False", "None"],
        "built_in": [
            // Встроенные функции
            "abs", "all", "any", "ascii", "bin", "bool", "breakpoint", "bytearray",
            "bytes", "callable", "chr", "classmethod", "compile", "complex", "delattr",
            "dict", "dir", "divmod", "enumerate", "eval", "exec", "filter", "float",
            "format", "frozenset", "getattr", "globals", "hasattr", "hash", "help",
            "hex", "id", "input", "int", "isinstance", "issubclass", "iter", "len",
            "list", "locals", "map", "max", "memoryview", "min", "next", "object",
            "oct", "open", "ord", "pow", "print", "property", "range", "repr",
            "reversed", "round", "set", "setattr", "slice", "sorted", "staticmethod",
            "str", "sum", "super", "tuple", "type", "vars", "zip",
            // Встроенные исключения
            "BaseException", "Exception", "ArithmeticError", "AssertionError",
            "AttributeError", "BlockingIOError", "BrokenPipeError", "BufferError",
            "BytesWarning", "ChildProcessError", "ConnectionError", "EOFError",
            "EnvironmentError", "FileExistsError", "FileNotFoundError", "FloatingPointError",
            "FutureWarning", "GeneratorExit", "IOError", "ImportError", "ImportWarning",
            "IndentationError", "IndexError", "InterruptedError", "IsADirectoryError",
            "KeyError", "KeyboardInterrupt", "LookupError", "MemoryError", "ModuleNotFoundError",
            "NameError", "NotADirectoryError", "NotImplementedError", "OSError",
            "Overflow Error", "PendingDeprecationWarning", "PermissionError", "ProcessLookupError",
            "RecursionError", "ReferenceError", "ResourceWarning", "RuntimeError",
            "RuntimeWarning", "StopAsyncIteration", "StopIteration", "SyntaxError",
            "SyntaxWarning", "SystemError", "SystemExit", "TabError", "TimeoutError",
            "TypeError", "UnboundLocalError", "UnicodeDecodeError", "UnicodeEncodeError",
            "UnicodeError", "UnicodeTranslateError", "UnicodeWarning", "UserWarning",
            "ValueError", "Warning", "ZeroDivisionError",
            // Специальные
            "__import__", "__name__", "__doc__", "__file__", "__dict__", "__class__",
            "self", "cls"
        ]
    ]
    let contains: [Mode] = [
        // Однострочные комментарии
        Mode(scope: "comment", begin: "#", end: "\n", contains: []),
        
        // Декораторы
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*(?:\\.[a-zA-Z_][a-zA-Z0-9_]*)*"),
        
        // Определение функций
        Mode(scope: "function", begin: "\\bdef\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Определение классов
        Mode(scope: "class", begin: "\\bclass\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Строки с тройными кавычками (многострочные)
        Mode(scope: "string", begin: "\"\"\"", end: "\"\"\"", contains: []),
        Mode(scope: "string", begin: "'''", end: "'''", contains: []),
        
        // f-строки (форматированные строки)
        Mode(scope: "string", begin: "f\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\{", end: "\\}", contains: [])
        ]),
        Mode(scope: "string", begin: "f'", end: "'", contains: [
            Mode(scope: "subst", begin: "\\{", end: "\\}", contains: [])
        ]),
        
        // Обычные строки
        CommonModes.stringDouble,
        CommonModes.stringSingle,
        
        // r-строки (raw strings)
        Mode(scope: "string", begin: "r\"(?:[^\"\\\\]|\\\\.)*\""),
        Mode(scope: "string", begin: "r'(?:[^'\\\\]|\\\\.)*'"),
        
        // Числа
        CommonModes.number,
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+\\b"), // Hex
        Mode(scope: "number", begin: "\\b0[oO][0-7]+\\b"),        // Octal
        Mode(scope: "number", begin: "\\b0[bB][01]+\\b"),         // Binary
    ]
}
