//
//  LuaLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct LuaLanguage: LanguageDefinition {
    let name = "Lua"
    let aliases: [String]? = ["lua"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
            "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return",
            "then", "true", "until", "while"
        ],
        "literal": ["true", "false", "nil"],
        "built_in": [
            // Basic functions
            "assert", "collectgarbage", "dofile", "error", "getmetatable",
            "setmetatable", "ipairs", "pairs", "load", "loadfile", "next",
            "pcall", "xpcall", "print", "rawequal", "rawget", "rawset", "rawlen",
            "select", "tonumber", "tostring", "type", "warn",
            // Lua 5.2+
            "require", "package", "_G", "_VERSION",
            // String library
            "string", "byte", "char", "dump", "find", "format", "gmatch", "gsub",
            "len", "lower", "match", "pack", "packsize", "rep", "reverse", "sub",
            "unpack", "upper",
            // String methods (can be called as string:method)
            "string.byte", "string.char", "string.dump", "string.find",
            "string.format", "string.gmatch", "string.gsub", "string.len",
            "string.lower", "string.match", "string.pack", "string.packsize",
            "string.rep", "string.reverse", "string.sub", "string.unpack",
            "string.upper",
            // Table library
            "table", "concat", "insert", "move", "pack", "remove", "sort", "unpack",
            "table.concat", "table.insert", "table.move", "table.pack",
            "table.remove", "table.sort", "table.unpack",
            // Math library
            "math", "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "cosh",
            "deg", "exp", "floor", "fmod", "frexp", "huge", "ldexp", "log", "log10",
            "max", "maxinteger", "min", "mininteger", "modf", "pi", "pow", "rad",
            "random", "randomseed", "sin", "sinh", "sqrt", "tan", "tanh", "tointeger",
            "type", "ult",
            "math.abs", "math.acos", "math.asin", "math.atan", "math.atan2",
            "math.ceil", "math.cos", "math.cosh", "math.deg", "math.exp",
            "math.floor", "math.fmod", "math.frexp", "math.huge", "math.ldexp",
            "math.log", "math.log10", "math.max", "math.maxinteger", "math.min",
            "math.mininteger", "math.modf", "math.pi", "math.pow", "math.rad",
            "math.random", "math.randomseed", "math.sin", "math.sinh", "math.sqrt",
            "math.tan", "math.tanh", "math.tointeger", "math.type", "math.ult",
            // IO library
            "io", "close", "flush", "input", "lines", "open", "output", "popen",
            "read", "tmpfile", "write", "stdin", "stdout", "stderr",
            "io.close", "io.flush", "io.input", "io.lines", "io.open", "io.output",
            "io.popen", "io.read", "io.tmpfile", "io.type", "io.write",
            "io.stdin", "io.stdout", "io.stderr",
            // File methods
            "file:close", "file:flush", "file:lines", "file:read", "file:seek",
            "file:setvbuf", "file:write",
            // OS library
            "os", "clock", "date", "difftime", "execute", "exit", "getenv",
            "remove", "rename", "setlocale", "time", "tmpname",
            "os.clock", "os.date", "os.difftime", "os.execute", "os.exit",
            "os.getenv", "os.remove", "os.rename", "os.setlocale", "os.time",
            "os.tmpname",
            // Debug library
            "debug", "gethook", "getinfo", "getlocal", "getmetatable", "getregistry",
            "getupvalue", "getuservalue", "sethook", "setlocal", "setmetatable",
            "setupvalue", "setuservalue", "traceback", "upvalueid", "upvaluejoin",
            "debug.debug", "debug.gethook", "debug.getinfo", "debug.getlocal",
            "debug.getmetatable", "debug.getregistry", "debug.getupvalue",
            "debug.getuservalue", "debug.sethook", "debug.setlocal",
            "debug.setmetatable", "debug.setupvalue", "debug.setuservalue",
            "debug.traceback", "debug.upvalueid", "debug.upvaluejoin",
            // Package library
            "package", "config", "cpath", "loaded", "loadlib", "path", "preload",
            "searchers", "searchpath",
            "package.config", "package.cpath", "package.loaded", "package.loadlib",
            "package.path", "package.preload", "package.searchers", "package.searchpath",
            // Coroutine library
            "coroutine", "create", "isyieldable", "resume", "running", "status",
            "wrap", "yield",
            "coroutine.create", "coroutine.isyieldable", "coroutine.resume",
            "coroutine.running", "coroutine.status", "coroutine.wrap",
            "coroutine.yield",
            // UTF8 library (Lua 5.3+)
            "utf8", "char", "charpattern", "codes", "codepoint", "len", "offset",
            "utf8.char", "utf8.charpattern", "utf8.codes", "utf8.codepoint",
            "utf8.len", "utf8.offset",
            // Bitwise operations (Lua 5.3+)
            "bit32", "arshift", "band", "bnot", "bor", "btest", "bxor", "extract",
            "lrotate", "lshift", "replace", "rrotate", "rshift",
            // Metatables and metamethods
            "__index", "__newindex", "__call", "__concat", "__unm", "__add",
            "__sub", "__mul", "__div", "__idiv", "__mod", "__pow", "__eq",
            "__lt", "__le", "__tostring", "__metatable", "__gc", "__mode",
            "__len", "__pairs", "__ipairs", "__close", "__name",
            // Special variables
            "_ENV", "_G", "_VERSION", "arg",
            // Common Lua patterns
            "self", "module", "export"
        ]
    ]
    let contains: [Mode] = [
        // Multi-line comments (block comments)
        Mode(scope: "comment", begin: "--\\[\\[", end: "\\]\\]"),
        Mode(scope: "comment", begin: "--\\[=\\[", end: "\\]=\\]"),
        Mode(scope: "comment", begin: "--\\[==\\[", end: "\\]==\\]"),
        
        // Single-line comments
        Mode(scope: "comment", begin: "--", end: "\n"),
        
        // Shebang
        Mode(scope: "comment", begin: "^#!", end: "\n"),
        
        // Function definitions
        Mode(scope: "function", begin: "\\bfunction\\s+(?:[a-zA-Z_][a-zA-Z0-9_]*[.:])?([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "function", begin: "\\blocal\\s+function\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Multi-line strings (long brackets)
        Mode(scope: "string", begin: "\\[\\[", end: "\\]\\]"),
        Mode(scope: "string", begin: "\\[=\\[", end: "\\]=\\]"),
        Mode(scope: "string", begin: "\\[==\\[", end: "\\]==\\]"),
        Mode(scope: "string", begin: "\\[===\\[", end: "\\]===\\]"),
        
        // Regular strings
        Mode(scope: "string", begin: "\"", end: "\""),
        Mode(scope: "string", begin: "'", end: "'"),
        
        // Numbers
        // Hex float (Lua 5.2+)
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+(?:\\.[0-9a-fA-F]+)?(?:[pP][+-]?[0-9]+)?\\b"),
        // Hex integer
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+\\b"),
        // Float with exponent
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*[eE][+-]?\\d+\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
        
        // Labels (goto targets) - Lua 5.2+
        Mode(scope: "meta", begin: "::[a-zA-Z_][a-zA-Z0-9_]*::"),
        
        // Table constructors (highlighting braces)
        Mode(scope: "meta", begin: "\\{", end: "\\}"),
    ]
}
