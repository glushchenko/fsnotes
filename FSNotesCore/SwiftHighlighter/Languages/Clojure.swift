//
//  Clojure.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 09.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct ClojureLanguage: LanguageDefinition {
    let name = "Clojure"
    let aliases: [String]? = ["clojure", "clj", "cljs", "cljc", "edn"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // Special forms
            "def", "if", "do", "let", "quote", "var", "fn", "loop", "recur",
            "throw", "try", "catch", "finally", "monitor-enter", "monitor-exit",
            // Defining forms
            "defn", "defn-", "defmacro", "defmethod", "defmulti", "defonce",
            "defprotocol", "defrecord", "defstruct", "deftype", "definterface",
            // Binding
            "let", "letfn", "binding", "with-bindings", "with-bindings*",
            "with-local-vars", "with-open", "with-precision", "with-redefs",
            "with-redefs-fn",
            // Conditionals
            "if", "if-not", "if-let", "if-some", "when", "when-not", "when-let",
            "when-some", "when-first", "cond", "condp", "case",
            // Loops
            "loop", "recur", "while", "dotimes", "doseq", "for", "doto",
            // Functions
            "fn", "defn", "defn-", "defmacro", "comp", "partial", "constantly",
            "identity", "complement", "juxt", "some-fn", "every-pred",
            // Java interop
            "new", ".", "..", "set!", "import", "gen-class", "gen-interface",
            "proxy", "proxy-super", "reify", "memfn", "bean",
            // Namespace
            "ns", "in-ns", "create-ns", "remove-ns", "require", "use", "import",
            "refer", "refer-clojure", "alias",
            // Vars
            "def", "defonce", "declare", "intern", "var",
            // Metadata
            "meta", "with-meta", "vary-meta", "alter-meta!", "reset-meta!",
            // Threading macros
            "->", "->>", "as->", "cond->", "cond->>", "some->", "some->>",
            // Logic
            "and", "or", "not", "not=",
            // Other
            "assert", "comment", "doc", "lazy-seq", "delay", "force", "promise",
            "deliver", "future", "future-call", "pmap", "pcalls", "pvalues"
        ],
        "literal": ["true", "false", "nil"],
        "built_in": [
            // Core functions - Collections
            "list", "list*", "vector", "vec", "hash-map", "hash-set", "sorted-map",
            "sorted-set", "sorted-map-by", "sorted-set-by", "seq", "cons", "conj",
            "concat", "lazy-cat", "mapcat", "cycle", "interleave", "interpose",
            "rest", "next", "butlast", "drop", "drop-while", "take", "take-nth",
            "take-while", "repeat", "replicate", "iterate", "range", "merge",
            "merge-with", "zipmap", "into", "reduce", "reduce-kv", "reductions",
            "set", "set/union", "set/intersection", "set/difference", "set/select",
            // Sequences
            "first", "second", "last", "rest", "next", "ffirst", "fnext", "nfirst",
            "nnext", "nth", "nthnext", "rand-nth", "when-first", "max-key", "min-key",
            "distinct", "filter", "remove", "keep", "keep-indexed", "for", "replace",
            "shuffle", "random-sample", "split-at", "split-with", "partition",
            "partition-all", "partition-by", "map", "map-indexed", "mapcat", "mapv",
            "pmap", "group-by", "frequencies", "reduce", "reductions", "transduce",
            // Collections - predicates
            "empty?", "not-empty", "seq?", "vector?", "list?", "map?", "set?",
            "coll?", "sequential?", "associative?", "sorted?", "counted?", "reversible?",
            // Collections - operations
            "count", "empty", "contains?", "get", "get-in", "assoc", "assoc-in",
            "dissoc", "update", "update-in", "select-keys", "rename-keys", "keys",
            "vals", "key", "val", "find", "peek", "pop", "conj", "disj",
            // Sequences - lazy
            "lazy-seq", "realized?", "doall", "dorun",
            // Strings
            "str", "subs", "format", "join", "escape", "split", "split-lines",
            "trim", "triml", "trimr", "trim-newline", "upper-case", "lower-case",
            "capitalize", "reverse", "replace", "replace-first", "re-find",
            "re-seq", "re-matches", "re-pattern", "re-matcher", "re-groups",
            // Numbers
            "inc", "dec", "max", "min", "abs", "+", "-", "*", "/", "quot", "rem",
            "mod", "bit-and", "bit-or", "bit-xor", "bit-not", "bit-shift-left",
            "bit-shift-right", "bit-flip", "bit-set", "bit-test", "bit-clear",
            "bit-and-not", "even?", "odd?", "zero?", "pos?", "neg?", "number?",
            "rational?", "integer?", "ratio?", "decimal?", "float?", "double?",
            // Math
            "rand", "rand-int", "rand-nth", "+", "-", "*", "/", "quot", "rem",
            "mod", "inc", "dec", "max", "min", "==", "<", ">", "<=", ">=",
            // Type predicates
            "nil?", "some?", "true?", "false?", "boolean?", "string?", "number?",
            "integer?", "int?", "pos-int?", "neg-int?", "nat-int?", "float?",
            "double?", "keyword?", "symbol?", "ident?", "simple-ident?",
            "qualified-ident?", "simple-symbol?", "qualified-symbol?",
            "simple-keyword?", "qualified-keyword?", "fn?", "ifn?", "coll?",
            "list?", "vector?", "map?", "set?", "seq?", "char?", "class?",
            "instance?", "var?", "identical?", "compare",
            // Functions
            "apply", "partial", "comp", "complement", "constantly", "identity",
            "fnil", "every-pred", "some-fn", "juxt", "memoize", "trampoline",
            // Atoms, Refs, Agents
            "atom", "swap!", "reset!", "compare-and-set!", "swap-vals!",
            "reset-vals!", "ref", "dosync", "ref-set", "alter", "commute",
            "ensure", "agent", "send", "send-off", "await", "await-for",
            "release-pending-sends", "restart-agent", "set-error-handler!",
            "set-error-mode!", "shutdown-agents", "add-watch", "remove-watch",
            // Vars
            "var-get", "var-set", "alter-var-root", "bound?", "thread-bound?",
            "with-bindings", "with-bindings*", "with-local-vars", "with-redefs",
            "push-thread-bindings", "pop-thread-bindings", "get-thread-bindings",
            // I/O
            "pr", "prn", "print", "println", "newline", "pr-str", "prn-str",
            "print-str", "println-str", "with-out-str", "with-in-str", "read",
            "read-line", "read-string", "slurp", "spit", "line-seq",
            // Namespaces
            "ns-name", "ns-map", "ns-interns", "ns-publics", "ns-imports",
            "ns-refers", "ns-aliases", "ns-resolve", "ns-unmap", "ns-unalias",
            "the-ns", "find-ns", "all-ns", "remove-ns", "symbol", "keyword",
            "namespace", "name", "gensym",
            // Evaluation
            "eval", "load", "load-file", "load-string", "load-reader",
            "requiring-resolve", "resolve", "macroexpand", "macroexpand-1",
            // Metadata
            "meta", "with-meta", "vary-meta", "alter-meta!", "reset-meta!",
            // Java interop
            "class", "type", "bases", "supers", "bean", "iterator-seq",
            "enumeration-seq", "format", "printf",
            // Transients
            "transient", "persistent!", "conj!", "assoc!", "dissoc!", "pop!",
            "disj!",
            // Sequences - sorting
            "sort", "sort-by", "sorted?", "compare",
            // Multimethods
            "defmulti", "defmethod", "remove-method", "remove-all-methods",
            "prefer-method", "methods", "get-method", "prefers",
            // Protocols
            "defprotocol", "extend", "extend-type", "extend-protocol", "reify",
            "satisfies?", "extenders",
            // Records and Types
            "defrecord", "deftype", "record?", "map->", "->",
            // Reducers
            "reduce", "fold", "filter", "remove", "map", "mapcat", "flatten",
            "take", "take-while", "drop", "drop-while",
            // Spec (clojure.spec.alpha)
            "def", "fdef", "keys", "valid?", "conform", "explain", "explain-str",
            "explain-data", "form", "describe", "assert", "check-asserts",
            // Testing
            "test", "deftest", "testing", "is", "are", "run-tests", "run-all-tests",
            // Core.async
            "go", "go-loop", "thread", "chan", "buffer", "dropping-buffer",
            "sliding-buffer", "timeout", "<!!", ">!!", "alts!!", "close!",
            "<!", ">!", "alts!", "alt!", "alt!!", "put!", "take!", "offer!",
            "poll!", "onto-chan!", "to-chan!", "pipe", "pipeline", "pipeline-async",
            "pipeline-blocking", "split", "mix", "admix", "unmix", "mult", "tap",
            "untap", "pub", "sub", "unsub", "unsub-all"
        ]
    ]
    let contains: [Mode] = [
        // Comments
        Mode(scope: "comment", begin: ";", end: "\n"),
        
        // Shebang
        Mode(scope: "comment", begin: "^#!", end: "\n"),
        
        // Discard form (reader macro)
        Mode(scope: "comment", begin: "#_"),
        
        // Keywords (with namespace support)
        Mode(scope: "meta", begin: "::?[a-zA-Z][a-zA-Z0-9*+!_?-]*(?:/[a-zA-Z][a-zA-Z0-9*+!_?-]*)?"),
        
        // Symbols (with namespace support)
        Mode(scope: "meta", begin: "[a-zA-Z*+!_?-][a-zA-Z0-9*+!_?-]*(?:/[a-zA-Z*+!_?-][a-zA-Z0-9*+!_?-]*)?"),
        
        // Regex literals
        Mode(scope: "string", begin: "#\"", end: "\""),
        
        // Strings
        CommonModes.stringDouble,
        
        // Characters
        Mode(scope: "string", begin: "\\\\(?:newline|space|tab|formfeed|backspace|return|u[0-9a-fA-F]{4}|o[0-7]{1,3}|.)"),
        
        // Anonymous function literal
        Mode(scope: "function", begin: "#\\("),
        
        // Set literal
        Mode(scope: "meta", begin: "#\\{"),
        
        // Var quote
        Mode(scope: "meta", begin: "#'"),
        
        // Tagged literals
        Mode(scope: "meta", begin: "#[a-zA-Z][a-zA-Z0-9*+!_?-]*(?:/[a-zA-Z][a-zA-Z0-9*+!_?-]*)?"),
        
        // Numbers
        // Ratio
        Mode(scope: "number", begin: "\\b[+-]?\\d+/\\d+\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b[+-]?0[xX][0-9a-fA-F]+N?\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b[+-]?0[0-7]+N?\\b"),
        // Scientific notation
        Mode(scope: "number", begin: "\\b[+-]?\\d+\\.?\\d*[eE][+-]?\\d+M?\\b"),
        // Float with M suffix (BigDecimal)
        Mode(scope: "number", begin: "\\b[+-]?\\d+\\.\\d+M\\b"),
        // Float
        Mode(scope: "number", begin: "\\b[+-]?\\d+\\.\\d+\\b"),
        // Integer with N suffix (BigInt)
        Mode(scope: "number", begin: "\\b[+-]?\\d+N\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b[+-]?\\d+\\b"),
    ]
}
