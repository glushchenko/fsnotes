//
//  DartLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct DartLanguage: LanguageDefinition {
    let name = "Dart"
    let aliases: [String]? = ["dart"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "abstract", "as", "assert", "async", "await", "break", "case", "catch",
            "class", "const", "continue", "covariant", "default", "deferred", "do",
            "dynamic", "else", "enum", "export", "extends", "extension", "external",
            "factory", "false", "final", "finally", "for", "Function", "get", "hide",
            "if", "implements", "import", "in", "interface", "is", "late", "library",
            "mixin", "new", "null", "on", "operator", "part", "required", "rethrow",
            "return", "sealed", "set", "show", "static", "super", "switch", "sync",
            "this", "throw", "true", "try", "typedef", "var", "void", "while", "with",
            "yield",
            // Dart 3.0+ keywords
            "base", "final", "interface", "mixin", "sealed", "when"
        ],
        "literal": ["true", "false", "null"],
        "built_in": [
            // Core types
            "int", "double", "num", "bool", "String", "Object", "Type", "Symbol",
            "List", "Set", "Map", "Runes", "StringBuffer", "RegExp", "Match",
            "Pattern", "DateTime", "Duration", "Uri", "Stopwatch",
            // Collections
            "Iterable", "Iterator", "LinkedHashMap", "LinkedHashSet", "HashMap",
            "HashSet", "SplayTreeMap", "SplayTreeSet", "Queue", "ListQueue",
            "DoubleLinkedQueue", "UnmodifiableListView", "UnmodifiableMapView",
            // Future and Stream
            "Future", "Stream", "StreamController", "StreamSubscription",
            "StreamTransformer", "Completer", "StreamSink", "EventSink",
            "FutureOr", "Zone", "ZoneSpecification",
            // Core functions
            "print", "identical", "identityHashCode",
            // Exceptions
            "Exception", "Error", "ArgumentError", "RangeError", "IndexError",
            "StateError", "UnsupportedError", "UnimplementedError", "CastError",
            "TypeError", "NoSuchMethodError", "NullThrownError", "FormatException",
            "IntegerDivisionByZeroException", "OutOfMemoryError", "StackOverflowError",
            "ConcurrentModificationError", "TimeoutException",
            // Math
            "Random", "Point", "Rectangle", "MutableRectangle",
            // Convert
            "Converter", "Codec", "Encoding", "utf8", "latin1", "ascii",
            "base64", "base64Url", "json", "JsonEncoder", "JsonDecoder",
            "JsonCodec", "LineSplitter", "StringConversionSink",
            // dart:io (common)
            "File", "Directory", "Link", "IOSink", "FileStat", "FileMode",
            "FileSystemEntity", "FileSystemEvent", "Platform", "stdin", "stdout",
            "stderr", "Process", "ProcessResult", "HttpClient", "HttpServer",
            "HttpRequest", "HttpResponse", "HttpHeaders", "Cookie", "WebSocket",
            "Socket", "ServerSocket", "RawSocket", "RawServerSocket",
            "InternetAddress", "NetworkInterface",
            // dart:async
            "Timer", "scheduleMicrotask", "runZoned", "runZonedGuarded",
            // dart:collection
            "LinkedList", "LinkedListEntry", "ListBase", "MapBase", "SetBase",
            "IterableBase", "UnmodifiableListBase", "UnmodifiableMapBase",
            // dart:typed_data
            "ByteData", "Endian", "Float32List", "Float64List", "Int8List",
            "Int16List", "Int32List", "Int64List", "Uint8List", "Uint16List",
            "Uint32List", "Uint64List", "Uint8ClampedList", "ByteBuffer",
            // Common methods
            "forEach", "map", "where", "reduce", "fold", "every", "any", "contains",
            "firstWhere", "lastWhere", "singleWhere", "take", "takeWhile", "skip",
            "skipWhile", "toList", "toSet", "join", "length", "isEmpty", "isNotEmpty",
            "first", "last", "single", "elementAt", "add", "addAll", "remove",
            "removeAt", "removeLast", "removeWhere", "retainWhere", "clear", "insert",
            "insertAll", "sort", "shuffle", "reversed", "indexOf", "lastIndexOf",
            "sublist", "getRange", "setRange", "fillRange", "replaceRange", "asMap",
            // String methods
            "substring", "trim", "trimLeft", "trimRight", "padLeft", "padRight",
            "startsWith", "endsWith", "split", "splitMapJoin", "replaceAll",
            "replaceFirst", "replaceRange", "toLowerCase", "toUpperCase",
            "compareTo", "codeUnitAt", "codeUnits", "runes", "characters",
            // Future methods
            "then", "catchError", "whenComplete", "timeout", "asStream",
            // Stream methods
            "listen", "asBroadcastStream", "where", "map", "asyncMap", "asyncExpand",
            "handleError", "expand", "take", "takeWhile", "skip", "skipWhile",
            "distinct", "first", "last", "single", "isEmpty", "length", "toList",
            "drain", "pipe", "transform", "reduce", "fold", "join", "contains",
            "any", "every", "firstWhere", "lastWhere", "singleWhere", "elementAt",
            // Flutter-related (common)
            "Widget", "StatelessWidget", "StatefulWidget", "State", "BuildContext",
            "Key", "GlobalKey", "ValueKey", "ObjectKey", "UniqueKey",
            "InheritedWidget", "BuildOwner", "Element", "RenderObject",
            // Annotations
            "override", "deprecated", "pragma", "required", "protected", "visibleForTesting",
            "immutable", "sealed", "nonVirtual", "mustCallSuper"
        ]
    ]
    let contains: [Mode] = [
        // Documentation comments
        Mode(scope: "comment.doc", begin: "///", end: "\n", contains: []),
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/", contains: []),
        
        // Многострочные комментарии
        Mode(scope: "comment", begin: "/\\*", end: "\\*/", contains: []),
        
        // Однострочные комментарии
        Mode(scope: "comment", begin: "//", end: "\n", contains: []),
        
        // Metadata/Annotations
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*"),
        
        // Определение классов
        Mode(scope: "class", begin: "\\b(?:class|enum|mixin|extension)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Определение интерфейсов (abstract class)
        Mode(scope: "class", begin: "\\babstract\\s+class\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Определение функций и методов
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\s*(?=\\()"),
        
        // Raw strings
        Mode(scope: "string", begin: "r\"\"\"", end: "\"\"\"", contains: []),
        Mode(scope: "string", begin: "r'''", end: "'''", contains: []),
        Mode(scope: "string", begin: "r\"", end: "\"", contains: []),
        Mode(scope: "string", begin: "r'", end: "'", contains: []),
        
        // Multi-line strings with interpolation
        Mode(scope: "string", begin: "\"\"\"", end: "\"\"\"", contains: [
            Mode(scope: "subst", begin: "\\$\\{", end: "\\}", contains: []),
            Mode(scope: "subst", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*")
        ]),
        Mode(scope: "string", begin: "'''", end: "'''", contains: [
            Mode(scope: "subst", begin: "\\$\\{", end: "\\}", contains: []),
            Mode(scope: "subst", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*")
        ]),
        
        // Regular strings with interpolation
        Mode(scope: "string", begin: "\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\$\\{", end: "\\}", contains: []),
            Mode(scope: "subst", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*")
        ]),
        Mode(scope: "string", begin: "'", end: "'", contains: [
            Mode(scope: "subst", begin: "\\$\\{", end: "\\}", contains: []),
            Mode(scope: "subst", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*")
        ]),
        
        // Symbols
        Mode(scope: "meta", begin: "#[a-zA-Z_][a-zA-Z0-9_]*"),
        
        // Числа
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+\\b"),
        // Scientific notation
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*[eE][+-]?\\d+\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
