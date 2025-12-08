//
//  KotlinLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct KotlinLanguage: LanguageDefinition {
    let name = "Kotlin"
    let aliases: [String]? = ["kt", "kts"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "abstract", "actual", "annotation", "as", "break", "by", "catch", "class",
            "companion", "const", "constructor", "continue", "crossinline", "data",
            "do", "dynamic", "else", "enum", "expect", "external", "final", "finally",
            "for", "fun", "get", "if", "import", "in", "infix", "init", "inline",
            "inner", "interface", "internal", "is", "lateinit", "noinline", "object",
            "open", "operator", "out", "override", "package", "private", "protected",
            "public", "reified", "return", "sealed", "set", "super", "suspend",
            "tailrec", "this", "throw", "try", "typealias", "typeof", "val", "var",
            "vararg", "when", "where", "while",
            // Soft keywords
            "by", "catch", "constructor", "delegate", "dynamic", "field", "file",
            "finally", "get", "import", "init", "param", "property", "receiver",
            "set", "setparam", "where",
            // Modifiers
            "actual", "abstract", "annotation", "companion", "const", "crossinline",
            "data", "enum", "expect", "external", "final", "infix", "inline", "inner",
            "internal", "lateinit", "noinline", "open", "operator", "out", "override",
            "private", "protected", "public", "reified", "sealed", "suspend", "tailrec",
            "vararg"
        ],
        "literal": ["true", "false", "null"],
        "built_in": [
            // Primitive types
            "Boolean", "Byte", "Char", "Double", "Float", "Int", "Long", "Short",
            "String", "Unit", "Nothing", "Any",
            // Unsigned types
            "UByte", "UShort", "UInt", "ULong",
            // Common types
            "Array", "BooleanArray", "ByteArray", "CharArray", "DoubleArray",
            "FloatArray", "IntArray", "LongArray", "ShortArray",
            "UByteArray", "UShortArray", "UIntArray", "ULongArray",
            "List", "MutableList", "Set", "MutableSet", "Map", "MutableMap",
            "ArrayList", "HashMap", "HashSet", "LinkedHashMap", "LinkedHashSet",
            "Collection", "MutableCollection", "Iterable", "MutableIterable",
            "Sequence", "Iterator", "MutableIterator", "ListIterator", "MutableListIterator",
            // Ranges
            "IntRange", "LongRange", "CharRange", "ClosedRange", "OpenEndRange",
            "IntProgression", "LongProgression", "CharProgression",
            // Result and optionals
            "Result", "Pair", "Triple",
            // Kotlin stdlib functions
            "print", "println", "readLine", "readln", "TODO", "require", "requireNotNull",
            "check", "checkNotNull", "error", "assert", "repeat", "run", "with", "let",
            "also", "apply", "takeIf", "takeUnless", "lazy", "runCatching",
            // Collections functions
            "listOf", "mutableListOf", "arrayListOf", "setOf", "mutableSetOf",
            "hashSetOf", "linkedSetOf", "sortedSetOf", "mapOf", "mutableMapOf",
            "hashMapOf", "linkedMapOf", "sortedMapOf", "emptyList", "emptySet",
            "emptyMap", "listOfNotNull", "arrayOf", "arrayOfNulls", "emptyArray",
            // String functions
            "buildString", "StringBuilder",
            // Coroutines
            "launch", "async", "runBlocking", "withContext", "coroutineScope",
            "supervisorScope", "delay", "yield", "Job", "Deferred", "CoroutineScope",
            "CoroutineContext", "Dispatchers", "Flow", "flow", "flowOf", "StateFlow",
            "SharedFlow", "Channel",
            // Delegates
            "Lazy", "ObservableProperty", "Delegates",
            // Reflection
            "KClass", "KFunction", "KProperty", "KType", "KCallable",
            // Annotations
            "Deprecated", "Suppress", "SuppressWarnings", "JvmStatic", "JvmField",
            "JvmOverloads", "JvmName", "Throws", "Synchronized", "Volatile", "Transient",
            // Exceptions
            "Exception", "RuntimeException", "IllegalArgumentException",
            "IllegalStateException", "IndexOutOfBoundsException", "NoSuchElementException",
            "NullPointerException", "ClassCastException", "NumberFormatException",
            "UnsupportedOperationException", "ArithmeticException",
            // Comparisons
            "Comparable", "Comparator",
            // Regex
            "Regex", "MatchResult", "MatchGroup",
            // Math
            "kotlin.math",
            // Standard functions
            "maxOf", "minOf", "coerceIn", "coerceAtLeast", "coerceAtMost"
        ]
    ]
    let contains: [Mode] = [
        // KDoc comments
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/"),
        
        // Multistring
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        
        // Onestring
        Mode(scope: "comment", begin: "//", end: "\n"),
        
        // Annotattions
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*(?:::[a-zA-Z_][a-zA-Z0-9_]*)?"),
        
        Mode(scope: "meta", begin: "[a-zA-Z_][a-zA-Z0-9_]*@"),
        
        Mode(scope: "class", begin: "\\b(?:class|interface|object|enum class|data class|sealed class|sealed interface|value class|annotation class)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        Mode(scope: "function", begin: "\\bfun\\s+(?:<[^>]*>\\s+)?([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        Mode(scope: "function", begin: "\\b(?:val|var)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        Mode(scope: "string", begin: "\"\"\"", end: "\"\"\""),
        Mode(scope: "string", begin: "\"", end: "\""),
        
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        
        Mode(scope: "number", begin: "\\b0[bB][01_]+[uU]?[lL]?\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F_]+[uU]?[lL]?\\b"),
        // Float/Double with suffixes
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\.[0-9_]+(?:[eE][+-]?[0-9_]+)?[fFdD]?\\b"),
        Mode(scope: "number", begin: "\\b\\d[0-9_]*[eE][+-]?[0-9_]+[fFdD]?\\b"),
        // Integer with underscores and suffixes
        Mode(scope: "number", begin: "\\b\\d[0-9_]*[uU]?[lL]?\\b"),
    ]
}
