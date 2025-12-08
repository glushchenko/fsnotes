//
//  VisualBasicLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct VbLanguage: LanguageDefinition {
    let name = "Visual Basic"
    let aliases: [String]? = ["vb", "vba", "vbnet", "vb.net"]
    let caseInsensitive = true
    let keywords: [String: [String]]? = [
        "keyword": [
            "AddHandler", "AddressOf", "Alias", "And", "AndAlso", "As", "Boolean",
            "ByRef", "Byte", "ByVal", "Call", "Case", "Catch", "CBool", "CByte",
            "CChar", "CDate", "CDbl", "CDec", "Char", "CInt", "Class", "CLng",
            "CObj", "Const", "Continue", "CSByte", "CShort", "CSng", "CStr",
            "CType", "CUInt", "CULng", "CUShort", "Date", "Decimal", "Declare",
            "Default", "Delegate", "Dim", "DirectCast", "Do", "Double", "Each",
            "Else", "ElseIf", "End", "EndIf", "Enum", "Erase", "Error", "Event",
            "Exit", "False", "Finally", "For", "Friend", "Function", "Get",
            "GetType", "GetXMLNamespace", "Global", "GoSub", "GoTo", "Handles",
            "If", "Implements", "Imports", "In", "Inherits", "Integer", "Interface",
            "Is", "IsNot", "Let", "Lib", "Like", "Long", "Loop", "Me", "Mod",
            "Module", "MustInherit", "MustOverride", "MyBase", "MyClass",
            "Namespace", "Narrowing", "New", "Next", "Not", "Nothing",
            "NotInheritable", "NotOverridable", "Object", "Of", "On", "Operator",
            "Option", "Optional", "Or", "OrElse", "Out", "Overloads", "Overridable",
            "Overrides", "ParamArray", "Partial", "Private", "Property", "Protected",
            "Public", "RaiseEvent", "ReadOnly", "ReDim", "REM", "RemoveHandler",
            "Resume", "Return", "SByte", "Select", "Set", "Shadows", "Shared",
            "Short", "Single", "Static", "Step", "Stop", "String", "Structure",
            "Sub", "SyncLock", "Then", "Throw", "To", "True", "Try", "TryCast",
            "TypeOf", "UInteger", "ULong", "UShort", "Using", "Variant", "Wend",
            "When", "While", "Widening", "With", "WithEvents", "WriteOnly", "Xor",
            // VB.NET async
            "Async", "Await", "Iterator", "Yield"
        ],
        "literal": ["True", "False", "Nothing", "vbTrue", "vbFalse", "vbNull", "vbEmpty"],
        "built_in": [
            // Data types
            "Boolean", "Byte", "Char", "Date", "Decimal", "Double", "Integer",
            "Long", "Object", "SByte", "Short", "Single", "String", "UInteger",
            "ULong", "UShort", "Variant",
            // Common classes
            "Array", "ArrayList", "Collection", "Dictionary", "List", "Queue",
            "Stack", "HashSet", "LinkedList", "SortedList", "SortedSet",
            "StringBuilder", "StringComparer", "Regex", "Match", "MatchCollection",
            "DateTime", "TimeSpan", "DateTimeOffset", "Guid", "Version", "Uri",
            // Conversion functions
            "CBool", "CByte", "CChar", "CDate", "CDbl", "CDec", "CInt", "CLng",
            "CObj", "CSByte", "CShort", "CSng", "CStr", "CType", "CUInt", "CULng",
            "CUShort", "Val", "Str", "Hex", "Oct", "Format", "FormatNumber",
            "FormatCurrency", "FormatPercent", "FormatDateTime",
            // String functions
            "Len", "Left", "Right", "Mid", "InStr", "InStrRev", "Replace", "StrComp",
            "StrConv", "String", "Space", "LCase", "UCase", "Trim", "LTrim", "RTrim",
            "Split", "Join", "Filter", "StrReverse", "Asc", "AscW", "Chr", "ChrW",
            // Math functions
            "Abs", "Atn", "Cos", "Exp", "Fix", "Int", "Log", "Rnd", "Sgn", "Sin",
            "Sqr", "Tan", "Ceiling", "Floor", "Round", "Max", "Min", "Sqrt", "Pow",
            // Array functions
            "UBound", "LBound", "IsArray", "Join", "Split", "Filter", "Array",
            "ReDim", "Erase",
            // File I/O
            "FileOpen", "FileClose", "FileGet", "FilePut", "Input", "LineInput",
            "Print", "Write", "FileAttr", "EOF", "Loc", "LOF", "Seek", "FileLen",
            "Dir", "ChDir", "ChDrive", "CurDir", "MkDir", "RmDir", "Kill", "Name",
            "FileCopy", "FileDateTime", "FileExists", "GetAttr", "SetAttr",
            "File", "FileInfo", "Directory", "DirectoryInfo", "Path", "StreamReader",
            "StreamWriter", "FileStream", "BinaryReader", "BinaryWriter",
            // Console I/O
            "MsgBox", "InputBox", "Console", "WriteLine", "ReadLine", "Write", "Read",
            // Type checking
            "IsNumeric", "IsDate", "IsArray", "IsError", "IsNothing", "IsDBNull",
            "IsReference", "TypeOf", "GetType", "TypeName", "VarType",
            // Control flow helpers
            "IIf", "Choose", "Switch",
            // Date/Time functions
            "Now", "Today", "TimeOfDay", "DateAdd", "DateDiff", "DatePart",
            "DateSerial", "DateValue", "Day", "Month", "Year", "Hour", "Minute",
            "Second", "Weekday", "WeekdayName", "MonthName", "TimeSerial", "TimeValue",
            "Timer",
            // Interaction functions
            "Shell", "AppActivate", "SendKeys", "Beep", "Environ", "Command",
            // Error handling
            "Err", "Error", "Erl", "On", "Resume", "Raise", "Clear", "Description",
            "Number", "Source", "Exception", "StackTrace",
            // Financial functions
            "DDB", "FV", "IPmt", "IRR", "MIRR", "NPer", "NPV", "Pmt", "PPmt",
            "PV", "Rate", "SLN", "SYD",
            // Miscellaneous
            "RGB", "QBColor", "CreateObject", "GetObject", "CallByName", "Partition",
            "InStrRev", "StrDup", "Like", "Randomize", "DoEvents",
            // Collections
            "Add", "Remove", "RemoveAt", "Clear", "Contains", "Count", "Item",
            "IndexOf", "Insert", "CopyTo", "ToArray",
            // LINQ (VB.NET)
            "From", "Where", "Select", "Order", "By", "Group", "Into", "Aggregate",
            "Join", "Let", "Skip", "Take", "Distinct", "Union", "Intersect", "Except",
            // Exceptions
            "Exception", "SystemException", "ApplicationException", "ArgumentException",
            "ArgumentNullException", "InvalidOperationException", "NotImplementedException",
            "NotSupportedException", "NullReferenceException", "IndexOutOfRangeException",
            "OverflowException", "DivideByZeroException", "FormatException", "IOException",
            "OutOfMemoryException",
            // System
            "Environment", "GC", "Math", "Random", "Convert", "BitConverter",
            "Buffer", "Activator", "AppDomain", "Type", "Assembly",
            // Threading
            "Thread", "ThreadPool", "Monitor", "Mutex", "Semaphore", "AutoResetEvent",
            "ManualResetEvent", "Task", "Parallel",
            // ADO.NET (common)
            "Connection", "Command", "DataReader", "DataAdapter", "DataSet", "DataTable",
            "DataRow", "DataColumn", "SqlConnection", "SqlCommand", "OleDbConnection",
            "OleDbCommand"
        ]
    ]
    let contains: [Mode] = [
        // XML Documentation comments
        Mode(scope: "comment.doc", begin: "'''", end: "\n"),
        
        // REM comments (legacy)
        Mode(scope: "comment", begin: "(?i)\\bREM\\b", end: "\n"),
        
        // Single quote comments
        Mode(scope: "comment", begin: "'", end: "\n"),
        
        // Preprocessor directives
        Mode(scope: "meta", begin: "^\\s*#(?:If|ElseIf|Else|End If|Region|End Region|Const|ExternalSource|End ExternalSource)\\b.*$"),
        
        // Attributes
        Mode(scope: "meta", begin: "<", end: ">"),
        
        // Labels (for GoTo)
        Mode(scope: "meta", begin: "^\\s*[a-zA-Z_][a-zA-Z0-9_]*:"),
        
        // Date literals
        Mode(scope: "string", begin: "#", end: "#"),
        
        // Strings with double quotes
        CommonModes.stringDouble,
        
        // Character literals (VB.NET)
        Mode(scope: "string", begin: "\"[cC]", end: "\""),
        
        // Numbers
        // Hex
        Mode(scope: "number", begin: "\\b&[hH][0-9a-fA-F]+[sSlL%&!#@]?\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b&[oO][0-7]+[sSlL%&!#@]?\\b"),
        // Binary (VB 14+)
        Mode(scope: "number", begin: "\\b&[bB][01]+[sSlL%&!#@]?\\b"),
        // Scientific notation
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*[eE][+-]?\\d+[fFdDrR]?\\b"),
        // Float with type suffix
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[fFdDrR]?\\b"),
        // Integer with type suffix
        Mode(scope: "number", begin: "\\b\\d+[sSlLiI%&!#@fFdDrR]\\b"),
        // Regular integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
