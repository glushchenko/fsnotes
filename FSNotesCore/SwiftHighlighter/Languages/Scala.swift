//
//  ScalaLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct ScalaLanguage: LanguageDefinition {
    let name = "Scala"
    let aliases: [String]? = ["scala", "sc"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "abstract", "case", "catch", "class", "def", "do", "else", "extends",
            "false", "final", "finally", "for", "forSome", "if", "implicit",
            "import", "lazy", "match", "new", "null", "object", "override",
            "package", "private", "protected", "return", "sealed", "super",
            "this", "throw", "trait", "try", "true", "type", "val", "var",
            "while", "with", "yield",
            // Scala 3 keywords
            "enum", "export", "given", "then", "using", "extension", "inline",
            "opaque", "open", "transparent", "infix", "end",
            // Contextual keywords
            "as", "derives", "macro"
        ],
        "literal": ["true", "false", "null"],
        "built_in": [
            // Basic types
            "Unit", "Boolean", "Byte", "Short", "Int", "Long", "Float", "Double",
            "Char", "String", "Symbol", "Any", "AnyRef", "AnyVal", "Nothing", "Null",
            // Collections - immutable
            "List", "Vector", "Set", "Map", "Seq", "Array", "ArrayBuffer",
            "IndexedSeq", "LinearSeq", "Queue", "Stack", "Stream", "LazyList",
            "Range", "NumericRange", "Iterator", "Iterable", "Traversable",
            "HashSet", "TreeSet", "BitSet", "ListSet",
            "HashMap", "TreeMap", "ListMap", "LinkedHashMap", "WeakHashMap",
            // Collections - mutable
            "ArraySeq", "ListBuffer", "ArrayBuffer", "StringBuilder",
            "HashSet", "LinkedHashSet", "TreeSet", "BitSet",
            "HashMap", "LinkedHashMap", "TreeMap", "WeakHashMap",
            "Queue", "Stack", "PriorityQueue", "ArrayDeque",
            // Option and Either
            "Option", "Some", "None", "Either", "Left", "Right",
            "Try", "Success", "Failure",
            // Tuple types
            "Tuple1", "Tuple2", "Tuple3", "Tuple4", "Tuple5", "Tuple6", "Tuple7",
            "Tuple8", "Tuple9", "Tuple10", "Tuple11", "Tuple12", "Tuple13", "Tuple14",
            "Tuple15", "Tuple16", "Tuple17", "Tuple18", "Tuple19", "Tuple20",
            "Tuple21", "Tuple22",
            // Function types
            "Function", "Function0", "Function1", "Function2", "Function3",
            "PartialFunction", "Function22",
            // Numeric types
            "BigInt", "BigDecimal", "Numeric", "Integral", "Fractional",
            "Ordering", "Ordered",
            // Common methods
            "map", "flatMap", "filter", "foreach", "fold", "foldLeft", "foldRight",
            "reduce", "reduceLeft", "reduceRight", "collect", "find", "exists",
            "forall", "count", "sum", "product", "min", "max", "minBy", "maxBy",
            "head", "tail", "headOption", "last", "lastOption", "init", "take",
            "drop", "takeWhile", "dropWhile", "slice", "splitAt", "span",
            "partition", "groupBy", "grouped", "sliding", "zip", "zipWithIndex",
            "unzip", "flatten", "distinct", "sorted", "sortBy", "sortWith",
            "reverse", "reverseMap", "contains", "containsSlice", "corresponds",
            "startsWith", "endsWith", "indexWhere", "lastIndexWhere", "indexOf",
            "lastIndexOf", "isEmpty", "nonEmpty", "size", "length", "mkString",
            // String methods
            "toUpperCase", "toLowerCase", "trim", "split", "replace", "replaceAll",
            "replaceFirst", "matches", "substring", "charAt", "concat",
            // Conversion methods
            "toList", "toVector", "toSet", "toMap", "toSeq", "toArray", "toStream",
            "toIterator", "toIndexedSeq", "toBuffer", "toString", "toInt", "toLong",
            "toDouble", "toFloat", "toBoolean", "toByte", "toShort", "toChar",
            // Concurrency
            "Future", "Promise", "Await", "ExecutionContext", "Executor",
            "Actor", "ActorRef", "ActorSystem", "Props", "Receive",
            // IO
            "Source", "BufferedSource", "Codec", "File", "Path", "URL", "URI",
            // Implicit conversions
            "implicitly", "Predef",
            // Scala objects
            "App", "Array", "Console", "List", "Nil", "StringContext",
            // Type classes
            "Numeric", "Ordering", "Equiv", "Manifest", "ClassTag", "TypeTag",
            "WeakTypeTag",
            // Reflection
            "reflect", "ClassTag", "TypeTag", "Mirror", "Universe",
            // XML (built-in)
            "Elem", "Node", "NodeSeq", "Text", "XML",
            // Common traits
            "Serializable", "Cloneable", "Product", "Equals",
            // Math
            "Math", "abs", "min", "max", "sqrt", "pow", "exp", "log", "log10",
            "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh",
            "tanh", "ceil", "floor", "round", "signum", "random",
            // Exceptions
            "Exception", "RuntimeException", "Throwable", "Error",
            "IllegalArgumentException", "IllegalStateException",
            "IndexOutOfBoundsException", "NoSuchElementException",
            "NullPointerException", "ClassCastException", "NumberFormatException",
            "UnsupportedOperationException", "ArithmeticException",
            "MatchError", "NotImplementedError",
            // Annotations
            "deprecated", "inline", "native", "specialized", "tailrec",
            "throws", "transient", "unchecked", "volatile", "SerialVersionUID",
            "annotation", "implicitNotFound", "implicitAmbiguous",
            // Scala 3 specific
            "CanEqual", "Matchable", "Singleton", "Selectable",
            // Common patterns
            "unapply", "apply", "update", "equals", "hashCode", "toString",
            "clone", "finalize", "getClass", "notify", "notifyAll", "wait",
            // Builder pattern
            "Builder", "CanBuildFrom", "IterableFactory",
            // Parallel collections
            "par", "ParSeq", "ParSet", "ParMap", "ParIterable"
        ]
    ]
    let contains: [Mode] = [
        // Scaladoc comments
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/", contains: []),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/", contains: []),
        Mode(scope: "comment", begin: "//", end: "\n", contains: []),
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*"),
        Mode(scope: "meta", begin: "'[a-zA-Z_][a-zA-Z0-9_]*\\b"),
        Mode(scope: "class", begin: "\\b(?:class|object|trait|enum|case class|case object)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "\\bpackage\\s+([a-zA-Z_][a-zA-Z0-9_.]*)", contains: []),
        Mode(scope: "function", begin: "\\bdef\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "meta", begin: "\\b(?:val|var)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // String interpolation
        Mode(scope: "string", begin: "s\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\$\\{", end: "\\}", contains: []),
            Mode(scope: "subst", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*")
        ]),
        Mode(scope: "string", begin: "f\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\$\\{", end: "\\}", contains: []),
            Mode(scope: "subst", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*")
        ]),
        
        // Raw strings
        Mode(scope: "string", begin: "raw\"", end: "\"", contains: []),
        
        // Triple-quoted strings (multiline)
        Mode(scope: "string", begin: "\"\"\"", end: "\"\"\"", contains: []),
        
        CommonModes.stringDouble,
        
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)'"),

        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+[lLfFdD]?\\b"),
        // Binary (Scala 2.13+)
        Mode(scope: "number", begin: "\\b0[bB][01]+[lL]?\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[0-7]+[lL]?\\b"),
        // Float/Double with suffixes
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+(?:[eE][+-]?\\d+)?[fFdD]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[eE][+-]?\\d+[fFdD]?\\b"),
        // Integer with suffix
        Mode(scope: "number", begin: "\\b\\d+[lLfFdD]\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
