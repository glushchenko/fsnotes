//
//  PhpLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 31.08.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct PHPLanguage: LanguageDefinition {
    let name = "PHP"
    let aliases: [String]? = ["php"]
    let caseInsensitive = false

    let keywords: [String: [String]]? = [
        "keyword": [
            "abstract","bool", "boolean", "class","final","public","private","protected","static","interface","trait","and","as","break","callable","case","catch","continue","declare","default",
            "do","double","else","elseif","empty","enddeclare","endfor","endforeach",
            "endif","endswitch","endwhile","enum","eval","extends","finally","for","foreach",
            "from","function","global","goto","if","implements","instanceof","insteadof",
            "int","integer","isset","iterable","list","match","mixed","new","never","object",
            "or","readonly","real","return","string","switch","throw","try","unset","use",
            "var","void","while","xor","yield","die","echo","exit","include","include_once",
            "print","require","require_once"
        ],
        "literal": ["true","false","null","TRUE","FALSE","NULL"],
        "built_in": [
            "ArrayAccess","BackedEnum","Closure","Error","AppendIterator","ArgumentCountError","ArithmeticError",
            "ArrayIterator","ArrayObject","AssertionError","BadFunctionCallException","BadMethodCallException",
            "CachingIterator","CallbackFilterIterator","CompileError","Countable","DirectoryIterator","DivisionByZeroError",
            "DomainException","EmptyIterator","ErrorException","Exception","FilesystemIterator","FilterIterator",
            "GlobIterator","InfiniteIterator","InvalidArgumentException","IteratorIterator","LengthException",
            "LimitIterator","LogicException","MultipleIterator","NoRewindIterator","OutOfBoundsException",
            "OutOfRangeException","OuterIterator","OverflowException","ParentIterator","ParseError","RangeException",
            "RecursiveArrayIterator","RecursiveCachingIterator","RecursiveCallbackFilterIterator","RecursiveDirectoryIterator",
            "RecursiveFilterIterator","RecursiveIterator","RecursiveIteratorIterator","RecursiveRegexIterator",
            "RecursiveTreeIterator","RegexIterator","RuntimeException","SeekableIterator","SplDoublyLinkedList",
            "SplFileInfo","SplFileObject","SplFixedArray","SplHeap","SplMaxHeap","SplMinHeap","SplObjectStorage",
            "SplObserver","SplPriorityQueue","SplQueue","SplStack","SplSubject","SplTempFileObject","TypeError",
            "UnderflowException","UnexpectedValueException","UnhandledMatchError","Stringable","Throwable",
            "Traversable","UnitEnum","WeakReference","WeakMap","Directory","__PHP_Incomplete_Class","parent","php_user_filter",
            "self","static","stdClass"
        ]
    ]

    let contains: [Mode] = [
        // Комментарии
        Mode(scope: "comment", begin: "//", end: "\n"),
        Mode(scope: "comment", begin: "#", end: "\n"),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),

        // Строки
        CommonModes.stringDouble,
        CommonModes.stringSingle,

        // Числа (в PHP есть hex, bin, oct, float с e)
        Mode(scope: "number", begin: "\\b(0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|\\d+(?:_\\d+)*(?:\\.\\d+(?:_\\d+)*)?(?:[eE][+-]?\\d+)?)\\b"),

        // Переменные
        Mode(scope: "variable", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*\\b"),

        // PHP-теги
        // PHP открывающие теги
        Mode(scope: "meta", begin: "<\\?php\\b"),
        Mode(scope: "meta", begin: "<\\?(?!=\\?)"),
        Mode(scope: "meta", begin: "\\?>"),

        Mode(
            scope: "class",
            begin: "\\b(?:class|interface|trait)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        // Для extends:
        Mode(
            scope: "class",
            begin: "\\bextends\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        // Для implements:
        Mode(
            scope: "class",
            begin: "\\bimplements\\s+([a-zA-Z_][a-zA-Z0-9_]*(?:\\s*,\\s*[a-zA-Z_][a-zA-Z0-9_]*)*)"
        ),

        // Для функций:
        Mode(
            scope: "function",
            begin: "\\b(?:fn|function)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        )
    ]
}
