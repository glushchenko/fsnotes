//
//  GroovyLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct GroovyLanguage: LanguageDefinition {
    let name = "Groovy"
    let aliases: [String]? = ["groovy", "gvy", "gy", "gsh"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "abstract", "as", "assert", "boolean", "break", "byte", "case", "catch",
            "char", "class", "const", "continue", "def", "default", "do", "double",
            "else", "enum", "extends", "false", "final", "finally", "float", "for",
            "goto", "if", "implements", "import", "in", "instanceof", "int", "interface",
            "long", "native", "new", "null", "package", "private", "protected", "public",
            "return", "short", "static", "strictfp", "super", "switch", "synchronized",
            "this", "throw", "throws", "trait", "transient", "true", "try", "void",
            "volatile", "while",
            // Groovy-specific
            "as", "def", "in", "trait", "var"
        ],
        "literal": ["true", "false", "null"],
        "built_in": [
            // Primitive wrapper classes
            "Boolean", "Byte", "Character", "Double", "Float", "Integer", "Long",
            "Number", "Short", "String", "Void",
            // Common classes
            "Object", "Class", "Closure", "Range", "Binding", "Script", "GroovyObject",
            "MetaClass", "ExpandoMetaClass", "Category", "Mixin",
            // Collections
            "Collection", "List", "ArrayList", "LinkedList", "Set", "HashSet",
            "LinkedHashSet", "TreeSet", "SortedSet", "Map", "HashMap", "LinkedHashMap",
            "TreeMap", "Hashtable", "Properties", "Queue", "Stack", "Vector",
            // GDK enhancements
            "each", "eachWithIndex", "collect", "collectMany", "findAll", "find",
            "findIndexOf", "findLastIndexOf", "grep", "every", "any", "inject",
            "sum", "max", "min", "sort", "unique", "reverse", "flatten", "transpose",
            "intersect", "disjoint", "plus", "minus", "multiply", "power", "div",
            "leftShift", "rightShift", "getAt", "putAt", "asType", "asBoolean",
            "split", "tokenize", "join", "reverse", "padLeft", "padRight", "center",
            "capitalize", "uncapitalize", "toUpperCase", "toLowerCase", "trim",
            "stripIndent", "stripMargin", "eachLine", "readLines", "splitEachLine",
            "withReader", "withWriter", "withStream", "withInputStream", "withOutputStream",
            "withPrintWriter", "eachFile", "eachDir", "eachFileRecurse", "eachDirRecurse",
            "eachFileMatch", "eachDirMatch", "traverse", "getText", "getBytes",
            "newReader", "newWriter", "newInputStream", "newOutputStream",
            "newPrintWriter", "append", "write", "leftShift",
            // I/O
            "File", "FileInputStream", "FileOutputStream", "FileReader", "FileWriter",
            "BufferedReader", "BufferedWriter", "InputStreamReader", "OutputStreamWriter",
            "PrintWriter", "PrintStream", "InputStream", "OutputStream", "Reader",
            "Writer", "RandomAccessFile",
            // Date/Time
            "Date", "Calendar", "GregorianCalendar", "TimeZone", "SimpleDateFormat",
            "DateFormat", "LocalDate", "LocalTime", "LocalDateTime", "ZonedDateTime",
            "Duration", "Period", "Instant",
            // Utilities
            "Random", "UUID", "Timer", "TimerTask", "Optional",
            // Regex
            "Pattern", "Matcher", "RegEx",
            // SQL/Database
            "Sql", "GroovyRowResult", "DataSet",
            // XML
            "XmlParser", "XmlSlurper", "MarkupBuilder", "StreamingMarkupBuilder",
            "Node", "NodeList", "GPathResult",
            // JSON
            "JsonSlurper", "JsonBuilder", "JsonOutput", "StreamingJsonBuilder",
            // HTTP/Network
            "URL", "URI", "URLConnection", "HttpURLConnection", "Socket",
            "ServerSocket", "InetAddress",
            // Swing (common in Groovy)
            "SwingBuilder", "JFrame", "JPanel", "JButton", "JLabel", "JTextField",
            "JTextArea", "JTable", "JList", "JTree", "JMenu", "JMenuItem",
            // Concurrency
            "Thread", "Runnable", "Callable", "Future", "ExecutorService",
            "ThreadPoolExecutor", "ScheduledExecutorService", "Lock", "ReentrantLock",
            "Semaphore", "CountDownLatch", "CyclicBarrier",
            // Groovy SQL
            "Sql", "DataSource", "Connection", "Statement", "PreparedStatement",
            "ResultSet", "ResultSetMetaData",
            // Exceptions
            "Exception", "RuntimeException", "Throwable", "Error",
            "IllegalArgumentException", "IllegalStateException", "NullPointerException",
            "IndexOutOfBoundsException", "ArrayIndexOutOfBoundsException",
            "ClassNotFoundException", "ClassCastException", "NumberFormatException",
            "IOException", "FileNotFoundException", "SQLException",
            // Annotations
            "Override", "Deprecated", "SuppressWarnings", "FunctionalInterface",
            "CompileStatic", "TypeChecked", "ToString", "EqualsAndHashCode",
            "TupleConstructor", "Canonical", "Immutable", "Singleton", "Delegate",
            "Lazy", "Newify", "Sortable", "Field", "PackageScope", "BaseScript",
            // AST Transformations
            "ASTTest", "AutoClone", "AutoExternalize", "Builder", "Canonical",
            "Category", "CompileDynamic", "CompileStatic", "Delegate", "EqualsAndHashCode",
            "ExternalizeMethods", "Field", "Grab", "GrabConfig", "GrabExclude",
            "GrabResolver", "Grapes", "Immutable", "IndexedProperty", "InheritConstructors",
            "Lazy", "ListenerList", "Log", "Memoized", "Mixin", "Newify",
            "NotYetImplemented", "PackageScope", "Singleton", "Sortable", "Synchronized",
            "ThreadInterrupt", "TimedInterrupt", "ToString", "TupleConstructor",
            "TypeChecked", "Vetoable", "VisibilityOptions", "WithReadLock", "WithWriteLock",
            // Testing (Spock, etc.)
            "Specification", "given", "when", "then", "expect", "where", "and",
            "cleanup", "setup", "setupSpec", "cleanupSpec",
            // Build tools (Gradle)
            "task", "tasks", "dependencies", "repositories", "buildscript",
            "allprojects", "subprojects", "apply", "plugin", "ext", "configurations",
            "sourceSets", "jar", "war", "test", "build", "clean", "assemble",
            "compile", "implementation", "api", "testImplementation", "testCompile"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/"),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        Mode(scope: "comment", begin: "//", end: "\n"),
        Mode(scope: "comment", begin: "^#!", end: "\n"),
        
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*(?:\\.[a-zA-Z_][a-zA-Z0-9_]*)*"),
        Mode(scope: "class", begin: "\\b(?:class|interface|trait|enum)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        Mode(scope: "function", begin: "\\b(?:def|void|public|private|protected|static)\\s+[a-zA-Z_][a-zA-Z0-9_]*\\s*(?=\\()"),
        
        // Triple-quoted strings (multi-line)
        Mode(scope: "string", begin: "\"\"\"", end: "\"\"\""),
        Mode(scope: "string", begin: "'''", end: "'''"),
        
        // Slashy strings (regex-friendly)
        Mode(scope: "string", begin: "/(?![*/])", end: "/"),
        
        // Dollar slashy strings
        Mode(scope: "string", begin: "\\$/", end: "/\\$"),
        
        // GString (interpolated strings)
        Mode(scope: "string", begin: "\"", end: "\""),
        
        // Regular strings (single quotes, no interpolation)
        CommonModes.stringSingle,
        
        // Character literals
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)'"),
        
        // Closures highlighting
        Mode(scope: "function", begin: "\\{", end: "\\}"),
        
        // Binary
        Mode(scope: "number", begin: "\\b0[bB][01]+[lLgGiI]?\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[0-7]+[lLgGiI]?\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+[lLgGiI]?\\b"),
        // Float/Double with suffixes
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+(?:[eE][+-]?\\d+)?[fFdDgG]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[eE][+-]?\\d+[fFdDgG]?\\b"),
        // BigDecimal (G suffix)
        Mode(scope: "number", begin: "\\b\\d+[gG]\\b"),
        // BigInteger (G or I suffix)
        Mode(scope: "number", begin: "\\b\\d+[iI]\\b"),
        // Long (L suffix)
        Mode(scope: "number", begin: "\\b\\d+[lL]\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
