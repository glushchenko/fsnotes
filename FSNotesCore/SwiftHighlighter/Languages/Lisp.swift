//
//  LispLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct LispLanguage: LanguageDefinition {
    let name = "Lisp"
    let aliases: [String]? = ["lisp", "cl", "common-lisp", "elisp", "emacs-lisp"]
    let caseInsensitive = true
    let keywords: [String: [String]]? = [
        "keyword": [
            // Special forms
            "quote", "function", "setq", "setf", "let", "let*", "flet", "labels",
            "macrolet", "symbol-macrolet", "if", "when", "unless", "cond", "case",
            "typecase", "and", "or", "prog1", "prog2", "progn", "progv", "go",
            "return", "return-from", "throw", "catch", "unwind-protect", "block",
            "tagbody", "multiple-value-call", "multiple-value-prog1", "the",
            "locally", "declare", "eval-when", "load-time-value",
            // Defining forms
            "defun", "defmacro", "defgeneric", "defmethod", "defclass", "defstruct",
            "deftype", "defvar", "defparameter", "defconstant", "define-compiler-macro",
            "define-modify-macro", "define-setf-expander", "define-symbol-macro",
            "defpackage", "in-package", "do-symbols", "do-external-symbols",
            "do-all-symbols",
            // Loop facility
            "loop", "do", "do*", "dotimes", "dolist",
            // Conditionals
            "if", "when", "unless", "cond", "case", "ecase", "typecase", "etypecase",
            "ctypecase",
            // Iteration
            "loop", "do", "do*", "dotimes", "dolist", "prog", "prog*",
            // Lambda
            "lambda", "function", "defun", "flet", "labels",
            // Macros
            "defmacro", "macrolet", "symbol-macrolet", "`", ",", ",@",
            // CLOS
            "defclass", "defgeneric", "defmethod", "call-next-method",
            "next-method-p", "slot-value", "with-slots", "with-accessors",
            "make-instance", "initialize-instance", "reinitialize-instance",
            "shared-initialize", "update-instance-for-different-class",
            "update-instance-for-redefined-class", "change-class",
            // Conditions
            "handler-case", "handler-bind", "ignore-errors", "define-condition",
            "make-condition", "signal", "error", "cerror", "warn", "invoke-restart",
            "invoke-restart-interactively", "restart-case", "restart-bind",
            "with-simple-restart", "abort", "continue", "muffle-warning",
            "store-value", "use-value",
            // Streams
            "with-open-file", "with-open-stream", "with-input-from-string",
            "with-output-to-string",
            // Other
            "values", "multiple-value-bind", "multiple-value-list",
            "multiple-value-setq", "nth-value"
        ],
        "literal": ["t", "nil"],
        "built_in": [
            // Predicates
            "null", "atom", "symbolp", "numberp", "integerp", "floatp", "rationalp",
            "complexp", "characterp", "stringp", "consp", "listp", "arrayp", "vectorp",
            "bit-vector-p", "simple-vector-p", "simple-string-p", "simple-bit-vector-p",
            "functionp", "compiled-function-p", "packagep", "streamp", "readtablep",
            "hash-table-p", "pathnamep", "typep", "subtypep", "standard-char-p",
            "graphic-char-p", "alpha-char-p", "upper-case-p", "lower-case-p",
            "both-case-p", "digit-char-p", "alphanumericp", "evenp", "oddp",
            "zerop", "plusp", "minusp", "boundp", "fboundp", "special-operator-p",
            "constantp", "eq", "eql", "equal", "equalp", "endp",
            // Numeric functions
            "+", "-", "*", "/", "1+", "1-", "abs", "mod", "rem", "floor", "ceiling",
            "truncate", "round", "sin", "cos", "tan", "asin", "acos", "atan", "sinh",
            "cosh", "tanh", "asinh", "acosh", "atanh", "exp", "expt", "log", "sqrt",
            "isqrt", "conjugate", "phase", "realpart", "imagpart", "numerator",
            "denominator", "rational", "rationalize", "gcd", "lcm", "max", "min",
            "signum", "random", "random-state-p", "make-random-state", "incf", "decf",
            "=", "/=", "<", ">", "<=", ">=",
            // Bit operations
            "logand", "logior", "logxor", "logeqv", "lognand", "lognor", "logandc1",
            "logandc2", "logorc1", "logorc2", "lognot", "logtest", "logbitp",
            "logcount", "ash", "integer-length", "boole", "boole-and", "boole-ior",
            "boole-xor", "boole-eqv", "boole-nand", "boole-nor", "boole-andc1",
            "boole-andc2", "boole-orc1", "boole-orc2", "boole-c1", "boole-c2",
            "boole-set", "boole-clr",
            // List functions
            "car", "cdr", "caar", "cadr", "cdar", "cddr", "caaar", "caadr", "cadar",
            "caddr", "cdaar", "cdadr", "cddar", "cdddr", "cons", "list", "list*",
            "append", "nconc", "revappend", "nreconc", "butlast", "nbutlast",
            "last", "ldiff", "tailp", "nthcdr", "nth", "first", "second", "third",
            "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
            "rest", "member", "member-if", "member-if-not", "assoc", "assoc-if",
            "assoc-if-not", "rassoc", "rassoc-if", "rassoc-if-not", "acons", "pairlis",
            "copy-list", "copy-alist", "copy-tree", "subst", "subst-if", "subst-if-not",
            "nsubst", "nsubst-if", "nsubst-if-not", "sublis", "nsublis", "tree-equal",
            "list-length", "make-list", "push", "pop", "pushnew", "adjoin",
            "union", "nunion", "intersection", "nintersection", "set-difference",
            "nset-difference", "set-exclusive-or", "nset-exclusive-or", "subsetp",
            "mapc", "mapcar", "mapcan", "mapl", "maplist", "mapcon",
            // Sequence functions
            "length", "elt", "reverse", "nreverse", "sort", "stable-sort", "find",
            "find-if", "find-if-not", "position", "position-if", "position-if-not",
            "count", "count-if", "count-if-not", "mismatch", "search", "substitute",
            "substitute-if", "substitute-if-not", "nsubstitute", "nsubstitute-if",
            "nsubstitute-if-not", "concatenate", "merge", "remove", "remove-if",
            "remove-if-not", "delete", "delete-if", "delete-if-not", "remove-duplicates",
            "delete-duplicates", "subseq", "copy-seq", "fill", "replace", "reduce",
            "map", "map-into", "some", "every", "notany", "notevery",
            // String functions
            "char", "schar", "string", "string=", "string/=", "string<", "string>",
            "string<=", "string>=", "string-equal", "string-not-equal", "string-lessp",
            "string-greaterp", "string-not-greaterp", "string-not-lessp",
            "string-upcase", "string-downcase", "string-capitalize", "nstring-upcase",
            "nstring-downcase", "nstring-capitalize", "string-trim", "string-left-trim",
            "string-right-trim", "make-string", "char-code", "code-char", "character",
            "char-upcase", "char-downcase", "char=", "char/=", "char<", "char>",
            "char<=", "char>=", "char-equal", "char-not-equal", "char-lessp",
            "char-greaterp", "char-not-greaterp", "char-not-lessp", "char-name",
            "name-char",
            // Array functions
            "make-array", "array-dimensions", "array-dimension", "array-total-size",
            "array-rank", "array-element-type", "array-row-major-index", "aref",
            "svref", "bit", "sbit", "vector", "vector-push", "vector-push-extend",
            "vector-pop", "adjust-array", "adjustable-array-p", "array-in-bounds-p",
            "array-has-fill-pointer-p", "fill-pointer", "row-major-aref",
            // Hash table functions
            "make-hash-table", "gethash", "remhash", "maphash", "clrhash",
            "hash-table-count", "hash-table-rehash-size", "hash-table-rehash-threshold",
            "hash-table-size", "hash-table-test", "sxhash", "with-hash-table-iterator",
            // Symbol functions
            "symbol-name", "symbol-package", "symbol-value", "symbol-function",
            "symbol-plist", "make-symbol", "copy-symbol", "gensym", "gentemp",
            "keywordp", "intern", "unintern", "find-symbol", "import", "shadowing-import",
            "shadow", "export", "unexport", "use-package", "unuse-package",
            // Package functions
            "make-package", "in-package", "find-package", "package-name",
            "package-nicknames", "rename-package", "package-use-list",
            "package-used-by-list", "package-shadowing-symbols", "list-all-packages",
            "delete-package", "find-all-symbols",
            // I/O functions
            "read", "read-preserving-whitespace", "read-delimited-list", "read-line",
            "read-char", "unread-char", "peek-char", "listen", "read-char-no-hang",
            "clear-input", "read-from-string", "parse-integer", "read-byte",
            "write", "prin1", "print", "pprint", "princ", "write-to-string",
            "prin1-to-string", "princ-to-string", "write-char", "write-string",
            "write-line", "terpri", "fresh-line", "finish-output", "force-output",
            "clear-output", "write-byte", "format",
            // Stream functions
            "input-stream-p", "output-stream-p", "interactive-stream-p",
            "open-stream-p", "stream-element-type", "streamp", "close",
            "broadcast-stream-streams", "concatenated-stream-streams",
            "echo-stream-input-stream", "echo-stream-output-stream",
            "make-broadcast-stream", "make-concatenated-stream", "make-echo-stream",
            "make-synonym-stream", "make-two-way-stream", "make-string-input-stream",
            "make-string-output-stream", "get-output-stream-string",
            "synonym-stream-symbol", "two-way-stream-input-stream",
            "two-way-stream-output-stream",
            // File functions
            "open", "close", "pathname", "truename", "parse-namestring",
            "merge-pathnames", "make-pathname", "pathnamep", "pathname-host",
            "pathname-device", "pathname-directory", "pathname-name", "pathname-type",
            "pathname-version", "namestring", "file-namestring", "directory-namestring",
            "host-namestring", "enough-namestring", "user-homedir-pathname",
            "directory", "probe-file", "ensure-directories-exist", "file-write-date",
            "file-author", "file-position", "file-length", "file-string-length",
            "load", "compile-file", "compile-file-pathname",
            // Control functions
            "apply", "funcall", "mapcar", "maplist", "mapc", "mapl", "mapcan",
            "mapcon", "values", "values-list", "constantp", "complement",
            // Evaluation
            "eval", "compile", "disassemble", "macro-function", "macroexpand",
            "macroexpand-1", "proclaim", "get-setf-expansion", "documentation",
            // Environment
            "apropos", "apropos-list", "describe", "inspect", "dribble", "ed",
            "lisp-implementation-type", "lisp-implementation-version",
            "machine-instance", "machine-type", "machine-version", "room",
            "software-type", "software-version", "short-site-name", "long-site-name",
            // Time functions
            "get-decoded-time", "get-universal-time", "decode-universal-time",
            "encode-universal-time", "get-internal-real-time",
            "get-internal-run-time", "sleep",
            // Error handling
            "error", "cerror", "warn", "signal", "break", "invoke-debugger",
            // Type functions
            "coerce", "type-of", "upgraded-array-element-type", "upgraded-complex-part-type"
        ]
    ]
    let contains: [Mode] = [
        // Comments
        Mode(scope: "comment", begin: ";", end: "\n"),
        
        // Block comments (some Lisp dialects)
        Mode(scope: "comment", begin: "#\\|", end: "\\|#"),
        
        // Shebang
        Mode(scope: "comment", begin: "^#!", end: "\n"),
        
        // Keywords (symbols starting with :)
        Mode(scope: "meta", begin: ":[a-zA-Z][a-zA-Z0-9-+*/_<>=!?]*"),
        
        // Quoted symbols
        Mode(scope: "meta", begin: "'[a-zA-Z][a-zA-Z0-9-+*/_<>=!?]*"),
        
        // Symbols
        Mode(scope: "meta", begin: "\\b[a-zA-Z][a-zA-Z0-9-+*/_<>=!?]*\\b"),
        
        // Strings
        CommonModes.stringDouble,
        
        // Character literals
        Mode(scope: "string", begin: "#\\\\(?:[a-zA-Z][a-zA-Z0-9-]*|.)"),
        
        // Numbers
        // Ratio
        Mode(scope: "number", begin: "[+-]?\\d+/\\d+"),
        // Complex
        Mode(scope: "number", begin: "#[cC]\\([+-]?\\d+(?:\\.\\d+)?\\s+[+-]?\\d+(?:\\.\\d+)?\\)"),
        // Float with exponent
        Mode(scope: "number", begin: "[+-]?\\d+(?:\\.\\d+)?[eEsSfFdDlL][+-]?\\d+"),
        // Float
        Mode(scope: "number", begin: "[+-]?\\d+\\.\\d+"),
        // Hex
        Mode(scope: "number", begin: "#[xX][0-9a-fA-F]+"),
        // Octal
        Mode(scope: "number", begin: "#[oO][0-7]+"),
        // Binary
        Mode(scope: "number", begin: "#[bB][01]+"),
        // Radix notation (base 2-36)
        Mode(scope: "number", begin: "#\\d+[rR][0-9a-zA-Z]+"),
        // Integer
        Mode(scope: "number", begin: "[+-]?\\d+"),
        
        // Arrays/vectors
        Mode(scope: "meta", begin: "#\\("),
        Mode(scope: "meta", begin: "#\\d*[aA]"),
        
        // Bit vectors
        Mode(scope: "meta", begin: "#\\*[01]*"),
        
        // Backquote and unquote
        Mode(scope: "keyword", begin: "`"),
        Mode(scope: "keyword", begin: ",@?"),
        
        // Function shorthand
        Mode(scope: "keyword", begin: "#'"),
        
        // Parentheses (for structure)
        Mode(scope: "keyword", begin: "\\("),
        Mode(scope: "keyword", begin: "\\)"),
    ]
}
