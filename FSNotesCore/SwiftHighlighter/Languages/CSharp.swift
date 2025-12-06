//
//  CSharpLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct CSharpLanguage: LanguageDefinition {
    let name = "C#"
    let aliases: [String]? = ["csharp", "cs"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "abstract", "as", "base", "break", "case", "catch", "checked", "class",
            "const", "continue", "default", "delegate", "do", "else", "enum", "event",
            "explicit", "extern", "finally", "fixed", "for", "foreach", "goto", "if",
            "implicit", "in", "interface", "internal", "is", "lock", "namespace", "new",
            "operator", "out", "override", "params", "private", "protected", "public",
            "readonly", "ref", "return", "sealed", "sizeof", "stackalloc", "static",
            "struct", "switch", "this", "throw", "try", "typeof", "unchecked", "unsafe",
            "using", "virtual", "void", "volatile", "while",
            // Contextual keywords
            "add", "alias", "ascending", "async", "await", "by", "descending", "dynamic",
            "equals", "from", "get", "global", "group", "init", "into", "join", "let",
            "nameof", "notnull", "on", "orderby", "partial", "record", "remove", "select",
            "set", "unmanaged", "value", "var", "when", "where", "with", "yield",
            // C# 9.0+
            "and", "not", "or", "nint", "nuint",
            // C# 10.0+
            "file", "required",
            // C# 11.0+
            "scoped"
        ],
        "literal": ["true", "false", "null"],
        "built_in": [
            // Primitive types
            "bool", "byte", "sbyte", "char", "decimal", "double", "float",
            "int", "uint", "long", "ulong", "short", "ushort", "object", "string",
            // Common types
            "String", "Object", "Boolean", "Byte", "SByte", "Char", "Decimal", "Double",
            "Single", "Int16", "Int32", "Int64", "UInt16", "UInt32", "UInt64",
            "DateTime", "DateTimeOffset", "TimeSpan", "Guid", "Uri", "Version",
            // Collections
            "Array", "List", "Dictionary", "HashSet", "Queue", "Stack", "LinkedList",
            "SortedList", "SortedDictionary", "SortedSet", "Collection", "ObservableCollection",
            "IEnumerable", "ICollection", "IList", "IDictionary", "ISet", "IReadOnlyCollection",
            "IReadOnlyList", "IReadOnlyDictionary",
            // System types
            "Exception", "SystemException", "ArgumentException", "ArgumentNullException",
            "InvalidOperationException", "NotImplementedException", "NotSupportedException",
            "NullReferenceException", "IndexOutOfRangeException", "OverflowException",
            "DivideByZeroException", "FormatException", "IOException", "OutOfMemoryException",
            // Nullable
            "Nullable",
            // Delegates and events
            "Action", "Func", "Predicate", "EventHandler", "EventArgs",
            // Tasks and async
            "Task", "ValueTask", "CancellationToken", "CancellationTokenSource",
            // LINQ
            "Enumerable", "Queryable", "IQueryable",
            // Attributes
            "Attribute", "Obsolete", "Serializable", "DllImport", "StructLayout",
            "MethodImpl", "CallerMemberName", "CallerFilePath", "CallerLineNumber",
            // StringBuilder
            "StringBuilder",
            // Regex
            "Regex", "Match", "MatchCollection", "Group", "Capture",
            // IO
            "File", "Directory", "Path", "FileStream", "StreamReader", "StreamWriter",
            "MemoryStream", "BinaryReader", "BinaryWriter", "FileInfo", "DirectoryInfo",
            // Reflection
            "Type", "Assembly", "MethodInfo", "PropertyInfo", "FieldInfo", "ConstructorInfo",
            "MemberInfo", "ParameterInfo",
            // Generics
            "IComparable", "IEquatable", "IDisposable", "IAsyncDisposable",
            "ICloneable", "IConvertible", "IFormattable", "IFormatProvider",
            // Threading
            "Thread", "ThreadPool", "Monitor", "Mutex", "Semaphore", "AutoResetEvent",
            "ManualResetEvent", "ReaderWriterLock", "ReaderWriterLockSlim",
            // Console
            "Console", "Environment",
            // Convert
            "Convert", "BitConverter", "Encoding",
            // Math
            "Math", "Random",
            // Tuple
            "Tuple", "ValueTuple"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "comment.doc", begin: "///", end: "\n"),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        Mode(scope: "comment", begin: "//", end: "\n"),
        
        Mode(scope: "meta", begin: "^\\s*#\\s*(?:if|else|elif|endif|define|undef|warning|error|line|region|endregion|pragma)\\b.*$"),
        Mode(scope: "meta", begin: "\\[", end: "\\]"),
        
        Mode(scope: "class", begin: "\\b(?:class|interface|struct|enum|record)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "\\bnamespace\\s+([a-zA-Z_][a-zA-Z0-9_.]*)"),
        
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\s*(?=\\()"),
        
        // Verbatim string literals
        Mode(scope: "string", begin: "@\"", end: "\""),
        
        // Interpolated strings
        Mode(scope: "string", begin: "\\$\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\{", end: "\\}")
        ]),
        
        // Verbatim interpolated strings
        Mode(scope: "string", begin: "\\$@\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\{", end: "\\}")
        ]),
        Mode(scope: "string", begin: "@\\$\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\{", end: "\\}")
        ]),
        
        // Raw string literals (C# 11)
        Mode(scope: "string", begin: "\"\"\"", end: "\"\"\""),
        
        CommonModes.stringDouble,
        
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)+'"),
        
        // Binary (C# 7.0+)
        Mode(scope: "number", begin: "\\b0[bB][01_]+(?:[uUlLfFdDmM]+)?\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F_]+(?:[uUlL]+)?\\b"),
        // Float/Double/Decimal with suffixes
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\.[0-9_]+(?:[eE][+-]?[0-9_]+)?[fFdDmM]?\\b"),
        Mode(scope: "number", begin: "\\b\\d[0-9_]*[eE][+-]?[0-9_]+[fFdDmM]?\\b"),
        // Integer with underscores (C# 7.0+)
        Mode(scope: "number", begin: "\\b\\d[0-9_]*(?:[uUlLfFdDmM]+)?\\b"),
    ]
}
