//
//  RubyLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct RubyLanguage: LanguageDefinition {
    let name = "Ruby"
    let aliases: [String]? = ["rb", "ruby", "rbw", "rake", "gemspec", "podspec", "thor", "irb"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "alias", "and", "begin", "break", "case", "class", "def", "defined?",
            "do", "else", "elsif", "end", "ensure", "for", "if", "in", "module",
            "next", "not", "or", "redo", "rescue", "retry", "return", "self", "super",
            "then", "undef", "unless", "until", "when", "while", "yield",
            // Special variables/constants
            "__FILE__", "__LINE__", "__ENCODING__",
            // Additional keywords
            "BEGIN", "END"
        ],
        "literal": ["true", "false", "nil"],
        "built_in": [
            // Core classes
            "Array", "BasicObject", "Binding", "Class", "Comparable", "Complex",
            "Data", "Dir", "Encoding", "Enumerator", "Enumerable", "ENV", "Exception",
            "FalseClass", "File", "FileTest", "Float", "GC", "Hash", "Integer", "IO",
            "Kernel", "Marshal", "MatchData", "Method", "Module", "Mutex", "NilClass",
            "Numeric", "Object", "ObjectSpace", "Proc", "Process", "Random", "Range",
            "Rational", "Regexp", "Signal", "String", "Struct", "Symbol", "Thread",
            "ThreadGroup", "Time", "TrueClass", "UnboundMethod",
            // Common methods
            "puts", "print", "printf", "p", "pp", "warn", "raise", "fail", "catch",
            "throw", "abort", "exit", "exit!", "at_exit", "gets", "readline", "readlines",
            "chomp", "chomp!", "chop", "chop!", "strip", "strip!", "lstrip", "lstrip!",
            "rstrip", "rstrip!", "upcase", "upcase!", "downcase", "downcase!",
            "capitalize", "capitalize!", "swapcase", "swapcase!", "reverse", "reverse!",
            "concat", "prepend", "insert", "delete", "delete!", "tr", "tr!", "squeeze",
            "squeeze!", "split", "scan", "match", "sub", "sub!", "gsub", "gsub!",
            "start_with?", "end_with?", "include?", "index", "rindex", "slice", "slice!",
            // Array methods
            "push", "pop", "shift", "unshift", "first", "last", "take", "drop",
            "each", "each_with_index", "each_index", "map", "collect", "select", "filter",
            "reject", "find", "detect", "find_all", "any?", "all?", "none?", "one?",
            "reduce", "inject", "sum", "min", "max", "minmax", "sort", "sort!", "sort_by",
            "reverse", "reverse!", "flatten", "flatten!", "compact", "compact!", "uniq",
            "uniq!", "zip", "transpose", "rotate", "rotate!", "sample", "shuffle",
            "shuffle!", "join", "concat", "length", "size", "count", "empty?",
            // Hash methods
            "keys", "values", "has_key?", "key?", "has_value?", "value?", "fetch",
            "store", "delete", "delete_if", "keep_if", "select!", "reject!", "merge",
            "merge!", "update", "invert", "to_a", "to_h", "transform_keys",
            "transform_values", "dig",
            // Enumerable methods
            "each_cons", "each_slice", "cycle", "take_while", "drop_while", "group_by",
            "partition", "chunk", "slice_before", "slice_after", "slice_when",
            // Numeric methods
            "abs", "ceil", "floor", "round", "truncate", "to_i", "to_f", "to_s", "to_r",
            "next", "succ", "pred", "times", "upto", "downto", "step", "even?", "odd?",
            "zero?", "positive?", "negative?", "finite?", "infinite?", "nan?",
            // String methods
            "chars", "bytes", "lines", "codepoints", "bytesize", "encoding", "force_encoding",
            "encode", "encode!", "intern", "to_sym", "ord", "chr", "center", "ljust",
            "rjust", "partition", "rpartition", "casecmp", "casecmp?", "hex", "oct",
            // File/IO methods
            "open", "read", "write", "close", "closed?", "eof", "eof?", "rewind",
            "seek", "pos", "tell", "flush", "sync", "binmode", "readlines", "each_line",
            "getc", "getbyte", "ungetc", "ungetbyte", "sysread", "syswrite",
            // File class methods
            "exist?", "exists?", "file?", "directory?", "dirname", "basename", "extname",
            "expand_path", "absolute_path", "realpath", "join", "split", "chmod",
            "chown", "delete", "unlink", "rename", "stat", "lstat", "mtime", "atime",
            "ctime", "size", "size?",
            // Object methods
            "class", "is_a?", "kind_of?", "instance_of?", "respond_to?", "methods",
            "instance_variables", "instance_variable_get", "instance_variable_set",
            "send", "public_send", "define_method", "define_singleton_method",
            "method_missing", "const_get", "const_set", "const_defined?",
            "ancestors", "included_modules", "superclass", "singleton_class",
            "freeze", "frozen?", "dup", "clone", "taint", "tainted?", "untaint",
            "trust", "untrust", "untrusted?", "tap", "then", "yield_self",
            "to_enum", "enum_for", "extend", "include", "prepend",
            // Kernel methods
            "require", "require_relative", "load", "autoload", "autoload?",
            "eval", "exec", "system", "spawn", "syscall", "test", "trap",
            "caller", "caller_locations", "binding", "block_given?", "iterator?",
            "lambda", "proc", "loop", "sleep", "rand", "srand", "format", "sprintf",
            // Comparable
            "between?", "clamp",
            // Math
            "sqrt", "exp", "log", "log10", "log2", "sin", "cos", "tan", "asin",
            "acos", "atan", "atan2", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
            // Module/Class methods
            "attr_reader", "attr_writer", "attr_accessor", "attr", "alias_method",
            "private", "protected", "public", "module_function", "remove_method",
            "undef_method", "method_defined?", "private_method_defined?",
            "protected_method_defined?", "public_method_defined?",
            // Exception classes
            "StandardError", "RuntimeError", "TypeError", "ArgumentError", "IndexError",
            "KeyError", "RangeError", "ScriptError", "SyntaxError", "LoadError",
            "NotImplementedError", "NameError", "NoMethodError", "IOError", "EOFError",
            "SystemCallError", "ZeroDivisionError", "FloatDomainError", "StopIteration",
            "LocalJumpError", "SystemExit", "Interrupt", "SignalException"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "comment.doc", begin: "^=begin", end: "^=end"),
        Mode(scope: "comment", begin: "#", end: "\n"),
        
        // Symbols
        Mode(scope: "meta", begin: ":[a-zA-Z_][a-zA-Z0-9_]*[!?=]?"),
        Mode(scope: "meta", begin: ":\"", end: "\""),
        Mode(scope: "meta", begin: ":'", end: "'"),
        
        // Instance variables
        Mode(scope: "meta", begin: "@[a-zA-Z_][a-zA-Z0-9_]*"),
        
        // Class variables
        Mode(scope: "meta", begin: "@@[a-zA-Z_][a-zA-Z0-9_]*"),
        
        // Global variables
        Mode(scope: "meta", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*"),
        Mode(scope: "meta", begin: "\\$[0-9]+"),
        Mode(scope: "meta", begin: "\\$[!@&`'+~=/\\\\,;.<>*$?:\"]"),

        Mode(scope: "class", begin: "\\bclass\\s+([A-Z][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "\\bmodule\\s+([A-Z][a-zA-Z0-9_]*)"),
        
        // Определение методов
        Mode(scope: "function", begin: "\\bdef\\s+(?:self\\.)?([a-zA-Z_][a-zA-Z0-9_]*[!?=]?)"),
        
        // Percent literals - strings
        Mode(scope: "string", begin: "%[qQ]?\\{", end: "\\}"),
        Mode(scope: "string", begin: "%[qQ]?\\[", end: "\\]"),
        Mode(scope: "string", begin: "%[qQ]?\\(", end: "\\)"),
        Mode(scope: "string", begin: "%[qQ]?<", end: ">"),
        Mode(scope: "string", begin: "%[qQ]?\\|", end: "\\|"),
        Mode(scope: "string", begin: "%[qQ]?/", end: "/"),
        
        // Percent literals - arrays
        Mode(scope: "string", begin: "%[wW]\\{", end: "\\}"),
        Mode(scope: "string", begin: "%[wW]\\[", end: "\\]"),
        Mode(scope: "string", begin: "%[wW]\\(", end: "\\)"),
        
        // Heredocs
        Mode(scope: "string", begin: "<<[-~]?['\"]?([A-Z_]+)['\"]?", end: "^\\1$"),
        
        // Regular expressions
        Mode(scope: "string", begin: "/(?![*/])", end: "/[imxo]*"),
        Mode(scope: "string", begin: "%r\\{", end: "\\}[imxo]*"),
        Mode(scope: "string", begin: "%r\\[", end: "\\][imxo]*"),
        Mode(scope: "string", begin: "%r\\(", end: "\\)[imxo]*"),
        Mode(scope: "string", begin: "%r<", end: ">[imxo]*"),
        Mode(scope: "string", begin: "%r\\|", end: "\\|[imxo]*"),
        
        // String interpolation
        Mode(scope: "string", begin: "\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "#\\{", end: "\\}")
        ]),
        
        // Single quoted strings (no interpolation)
        CommonModes.stringSingle,
        
        // Backtick strings (command execution)
        Mode(scope: "string", begin: "`", end: "`", contains: [
            Mode(scope: "subst", begin: "#\\{", end: "\\}")
        ]),
        
        // Binary
        Mode(scope: "number", begin: "\\b0[bB][01_]+\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[oO][0-7_]+\\b"),
        Mode(scope: "number", begin: "\\b0[0-7_]+\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F_]+\\b"),
        // Float with exponent
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\.\\d[0-9_]*[eE][+-]?\\d[0-9_]*\\b"),
        Mode(scope: "number", begin: "\\b\\d[0-9_]*[eE][+-]?\\d[0-9_]*\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\.\\d[0-9_]*\\b"),
        // Integer with underscores
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\b"),
    ]
}
