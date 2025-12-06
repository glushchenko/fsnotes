//
//  JavaLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct JavaLanguage: LanguageDefinition {
    let name = "Java"
    let aliases: [String]? = ["java", "jsp"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "abstract", "assert", "boolean", "break", "byte", "case", "catch",
            "char", "class", "const", "continue", "default", "do", "double",
            "else", "enum", "extends", "final", "finally", "float", "for",
            "goto", "if", "implements", "import", "instanceof", "int", "interface",
            "long", "native", "new", "package", "private", "protected", "public",
            "return", "short", "static", "strictfp", "super", "switch", "synchronized",
            "this", "throw", "throws", "transient", "try", "void", "volatile", "while",
            // Java 9+
            "module", "requires", "exports", "opens", "to", "uses", "provides", "with",
            // Java 10+
            "var",
            // Java 14+
            "record", "sealed", "permits", "non-sealed",
            // Java 17+
            "yield"
        ],
        "literal": ["true", "false", "null"],
        "built_in": [
            // Primitive wrapper classes
            "Boolean", "Byte", "Character", "Double", "Float", "Integer", "Long", "Short",
            "Void", "Number",
            // Common classes
            "Object", "String", "StringBuffer", "StringBuilder", "Class", "System",
            "Thread", "Runnable", "Throwable", "Exception", "Error", "RuntimeException",
            // Collections
            "Collection", "List", "ArrayList", "LinkedList", "Vector", "Stack",
            "Set", "HashSet", "LinkedHashSet", "TreeSet", "SortedSet", "NavigableSet",
            "Map", "HashMap", "LinkedHashMap", "TreeMap", "Hashtable", "SortedMap", "NavigableMap",
            "Queue", "Deque", "PriorityQueue", "ArrayDeque",
            "Collections", "Arrays", "Iterator", "ListIterator", "Enumeration",
            // I/O
            "File", "FileInputStream", "FileOutputStream", "FileReader", "FileWriter",
            "BufferedReader", "BufferedWriter", "InputStreamReader", "OutputStreamWriter",
            "InputStream", "OutputStream", "Reader", "Writer", "PrintStream", "PrintWriter",
            "Scanner", "Console",
            // Utilities
            "Date", "Calendar", "GregorianCalendar", "TimeZone", "Locale",
            "Random", "UUID", "Optional", "Objects",
            "Math", "StrictMath",
            // Concurrency
            "Executor", "ExecutorService", "Callable", "Future", "CompletableFuture",
            "Lock", "ReentrantLock", "Semaphore", "CountDownLatch", "CyclicBarrier",
            "Atomic", "AtomicInteger", "AtomicLong", "AtomicBoolean", "AtomicReference",
            // Streams (Java 8+)
            "Stream", "IntStream", "LongStream", "DoubleStream", "Collector", "Collectors",
            // Functional interfaces (Java 8+)
            "Function", "BiFunction", "Consumer", "BiConsumer", "Supplier",
            "Predicate", "BiPredicate", "UnaryOperator", "BinaryOperator",
            // Exceptions
            "IOException", "FileNotFoundException", "SQLException", "ClassNotFoundException",
            "IllegalArgumentException", "IllegalStateException", "NullPointerException",
            "IndexOutOfBoundsException", "ArrayIndexOutOfBoundsException",
            "ConcurrentModificationException", "UnsupportedOperationException",
            "NumberFormatException", "ArithmeticException", "ClassCastException",
            // Annotations
            "Override", "Deprecated", "SuppressWarnings", "SafeVarargs", "FunctionalInterface",
            // Reflection
            "Method", "Field", "Constructor", "Modifier",
            // Generics helpers
            "Comparable", "Comparator", "Cloneable", "Serializable", "AutoCloseable"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/"),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        
        // Однострочные комментарии
        Mode(scope: "comment", begin: "//", end: "\n"),
        
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*(?:\\.[a-zA-Z_][a-zA-Z0-9_]*)*"),
        
        Mode(scope: "class", begin: "\\b(?:class|interface|enum|record)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\s*(?=\\()"),
        
        // Text blocks (Java 15+)
        Mode(scope: "string", begin: "\"\"\"", end: "\"\"\""),
        
        CommonModes.stringDouble,
        
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        
        // Binary (Java 7+)
        Mode(scope: "number", begin: "\\b0[bB][01]+[lLfFdD]?\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+[lLfFdD]?\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[0-7]+[lL]?\\b"),
        // Float/Double with suffixes
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[fFdD]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[eE][+-]?\\d+[fFdD]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[eE][+-]?\\d+[fFdD]?\\b"),
        // Integer with underscores (Java 7+)
        Mode(scope: "number", begin: "\\b\\d+(?:_\\d+)*[lLfFdD]?\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+[lLfFdD]?\\b"),
    ]
}
