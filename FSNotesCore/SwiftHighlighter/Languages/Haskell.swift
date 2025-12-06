//
//  HaskellLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct HaskellLanguage: LanguageDefinition {
    let name = "Haskell"
    let aliases: [String]? = ["haskell", "hs"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "as", "case", "of", "class", "data", "family", "instance", "default",
            "deriving", "do", "forall", "foreign", "hiding", "if", "then", "else",
            "import", "infix", "infixl", "infixr", "let", "in", "mdo", "module",
            "newtype", "proc", "qualified", "rec", "type", "where",
            // GHC extensions
            "pattern", "role", "via", "stock", "anyclass", "newtype",
            // Special keywords
            "safe", "unsafe", "interruptible", "ccall", "stdcall", "cplusplus",
            "jvm", "dotnet"
        ],
        "literal": ["True", "False"],
        "built_in": [
            // Basic types
            "Bool", "Char", "String", "Int", "Integer", "Float", "Double",
            "Rational", "Word", "IO", "Maybe", "Either", "Ordering",
            // Type constructors
            "Just", "Nothing", "Left", "Right", "LT", "EQ", "GT",
            // List types
            "[]", "[a]",
            // Tuple types
            "()", "(,)", "(,,)", "(,,,)", "(,,,,)",
            // Numeric types
            "Int8", "Int16", "Int32", "Int64",
            "Word8", "Word16", "Word32", "Word64",
            "Natural", "Scientific",
            // Function types
            "->", "=>",
            // Type classes
            "Eq", "Ord", "Show", "Read", "Enum", "Bounded", "Num", "Real",
            "Integral", "Fractional", "Floating", "RealFrac", "RealFloat",
            "Semigroup", "Monoid", "Functor", "Applicative", "Monad",
            "Alternative", "MonadPlus", "Foldable", "Traversable",
            "Category", "Arrow", "ArrowChoice", "ArrowApply", "ArrowLoop",
            // Common functions
            "map", "filter", "foldr", "foldl", "foldr1", "foldl1", "foldMap",
            "scanr", "scanl", "scanr1", "scanl1", "iterate", "repeat", "replicate",
            "cycle", "take", "drop", "takeWhile", "dropWhile", "splitAt", "span",
            "break", "reverse", "zip", "zip3", "zipWith", "zipWith3", "unzip",
            "unzip3", "concat", "concatMap", "and", "or", "any", "all", "sum",
            "product", "maximum", "minimum", "elem", "notElem", "lookup",
            "head", "last", "tail", "init", "null", "length",
            // List comprehensions helpers
            "enumFrom", "enumFromTo", "enumFromThen", "enumFromThenTo",
            // Functor/Applicative/Monad
            "fmap", "<$>", "<*>", "*>", "<*", "pure", "return", ">>=", ">>",
            "fail", "join", "liftM", "liftM2", "liftM3", "liftM4", "liftM5",
            "ap", "liftA", "liftA2", "liftA3", "<|>", "empty", "guard",
            "when", "unless", "forever", "void", "mapM", "mapM_", "forM",
            "forM_", "sequence", "sequence_", "replicateM", "replicateM_",
            "filterM", "zipWithM", "zipWithM_", "foldM", "foldM_",
            // Foldable/Traversable
            "fold", "foldMap", "foldr", "foldl", "foldr1", "foldl1", "toList",
            "null", "length", "elem", "maximum", "minimum", "sum", "product",
            "traverse", "sequenceA", "mapM", "sequence",
            // Maybe
            "maybe", "isJust", "isNothing", "fromJust", "fromMaybe",
            "listToMaybe", "maybeToList", "catMaybes", "mapMaybe",
            // Either
            "either", "lefts", "rights", "partitionEithers", "isLeft", "isRight",
            "fromLeft", "fromRight",
            // Bool
            "bool", "not", "otherwise",
            // Tuple
            "fst", "snd", "curry", "uncurry", "swap",
            // Char/String
            "lines", "words", "unlines", "unwords", "showChar", "showString",
            "readParen", "showParen", "lex", "reads", "shows", "read", "show",
            // Numeric functions
            "abs", "signum", "negate", "recip", "div", "mod", "quot", "rem",
            "divMod", "quotRem", "gcd", "lcm", "sqrt", "exp", "log", "logBase",
            "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh",
            "tanh", "asinh", "acosh", "atanh", "pi", "(**)", "(^)", "(^^)",
            "fromIntegral", "realToFrac", "truncate", "round", "ceiling", "floor",
            "toInteger", "toRational", "properFraction", "even", "odd", "succ", "pred",
            // Comparison
            "compare", "max", "min", "comparing", "on",
            // Function composition
            ".", "$", "$!", "flip", "const", "id", "until", "asTypeOf", "error",
            "errorWithoutStackTrace", "undefined", "seq", "deepseq", "force",
            // IO
            "putChar", "putStr", "putStrLn", "print", "getChar", "getLine",
            "getContents", "interact", "readFile", "writeFile", "appendFile",
            "readIO", "readLn",
            // Control structures
            "if", "then", "else", "case", "of", "let", "in", "where", "do",
            // Data structures
            "Map", "Set", "IntMap", "IntSet", "Seq", "Array", "Vector",
            "HashMap", "HashSet", "Text", "ByteString",
            // Common modules functions
            "insert", "delete", "member", "notMember", "lookup", "findWithDefault",
            "empty", "singleton", "fromList", "toList", "union", "intersection",
            "difference", "null", "size", "map", "filter", "partition",
            // Text/ByteString
            "pack", "unpack", "append", "concat", "intercalate", "split",
            "splitOn", "strip", "stripPrefix", "stripSuffix", "replace",
            "toLower", "toUpper", "reverse", "length", "null", "empty",
            // Parser combinators (common)
            "parse", "parseTest", "runParser", "many", "some", "optional",
            "between", "sepBy", "sepBy1", "endBy", "endBy1", "count", "chainl",
            "chainl1", "chainr", "chainr1", "choice", "option", "optionMaybe",
            "try", "lookAhead", "notFollowedBy",
            // Exceptions
            "Exception", "SomeException", "IOException", "ArithException",
            "ArrayException", "AssertionFailed", "AsyncException",
            "BlockedIndefinitelyOnMVar", "BlockedIndefinitelyOnSTM",
            "Deadlock", "ErrorCall", "NoMethodError", "PatternMatchFail",
            "RecConError", "RecSelError", "RecUpdError", "TypeError",
            "catch", "catchJust", "handle", "handleJust", "try", "tryJust",
            "evaluate", "throw", "throwIO", "throwTo", "assert", "finally",
            "bracket", "bracket_", "bracketOnError", "onException",
            // Concurrency
            "forkIO", "forkOS", "forkOn", "forkIOWithUnmask", "killThread",
            "threadDelay", "yield", "myThreadId", "throwTo", "MVar", "newMVar",
            "newEmptyMVar", "takeMVar", "putMVar", "readMVar", "swapMVar",
            "tryTakeMVar", "tryPutMVar", "isEmptyMVar", "withMVar", "modifyMVar",
            "modifyMVar_", "Chan", "newChan", "writeChan", "readChan", "dupChan",
            "STM", "atomically", "retry", "orElse", "TVar", "newTVar", "readTVar",
            "writeTVar", "modifyTVar", "modifyTVar'", "swapTVar",
            // Prelude re-exports
            "undefined", "error", "trace", "traceShow", "traceShowId"
        ]
    ]
    let contains: [Mode] = [
        // Block comments (nested)
        Mode(scope: "comment", begin: "\\{-", end: "-\\}"),
        
        // Line comments
        Mode(scope: "comment", begin: "--", end: "\n"),
        
        // Pragmas
        Mode(scope: "meta", begin: "\\{-#", end: "#-\\}"),
        
        // Module declaration
        Mode(scope: "class", begin: "\\bmodule\\s+([A-Z][a-zA-Z0-9_]*(?:\\.[A-Z][a-zA-Z0-9_]*)*)"),
        
        // Type declarations
        Mode(scope: "class", begin: "\\b(?:data|newtype|type|class|instance)\\s+([A-Z][a-zA-Z0-9_]*)"),
        
        // Constructors (capital letter start)
        Mode(scope: "class", begin: "\\b[A-Z][a-zA-Z0-9_]*\\b"),
        
        // Function definitions
        Mode(scope: "function", begin: "^[a-z_][a-zA-Z0-9_']*\\s*(?:::|=)"),
        
        // Type variables (lowercase in type signatures)
        Mode(scope: "meta", begin: "\\b[a-z][a-zA-Z0-9_']*\\b(?=.*::)"),
        
        // Operators (custom)
        Mode(scope: "keyword", begin: "(?:[!#$%&*+./<=>?@\\\\^|~-]+|`[a-zA-Z_][a-zA-Z0-9_']*`)"),
        
        // Character literals
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\(?:[abfnrtv\\\\\"'&]|o[0-7]+|x[0-9a-fA-F]+|[0-9]+|\\^[@-_]|NUL|SOH|STX|ETX|EOT|ENQ|ACK|BEL|BS|HT|LF|VT|FF|CR|SO|SI|DLE|DC1|DC2|DC3|DC4|NAK|SYN|ETB|CAN|EM|SUB|ESC|FS|GS|RS|US|SP|DEL))'"),
        
        // String literals
        Mode(scope: "string", begin: "\"", end: "\""),
        
        // Multi-line strings (with backslash continuation)
        Mode(scope: "string", begin: "\"", end: "\""),
        
        // Numbers
        // Binary (GHC 7.10+)
        Mode(scope: "number", begin: "\\b0[bB][01]+\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[oO][0-7]+\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+\\b"),
        // Float with exponent
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+(?:[eE][+-]?\\d+)?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[eE][+-]?\\d+\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
