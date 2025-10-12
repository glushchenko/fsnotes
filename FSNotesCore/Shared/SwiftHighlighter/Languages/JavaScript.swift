//
//  JavaScriptLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 31.08.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct JavaScriptLanguage: LanguageDefinition {
    let name = "JavaScript"
    let aliases: [String]? = ["js", "jsx", "mjs", "cjs"]
    let caseInsensitive = false

    let keywords: [String: [String]]? = [
        "keyword": [
            "constructor","this","as","in","of","if","for","while","finally","var","new","function",
            "do","return","void","else","break","catch","instanceof","with",
            "throw","case","default","try","switch","continue","typeof","delete",
            "let","yield","const","class","debugger","async","await","static",
            "import","from","export","extends","using"
        ],
        "literal": ["true","false","null","undefined","NaN","Infinity"],
        "built_in": [
            "Object","Function","Boolean","Symbol","Math","Date","Number","BigInt",
            "String","RegExp","Array","Float32Array","Float64Array","Int8Array",
            "Uint8Array","Uint8ClampedArray","Int16Array","Int32Array","Uint16Array",
            "Uint32Array","BigInt64Array","BigUint64Array","Set","Map","WeakSet",
            "WeakMap","ArrayBuffer","SharedArrayBuffer","Atomics","DataView","JSON",
            "Promise","Generator","GeneratorFunction","AsyncFunction","Reflect","Proxy",
            "Intl","WebAssembly","Error","EvalError","InternalError","RangeError",
            "ReferenceError","SyntaxError","TypeError","URIError",
            "console","window","document","localStorage","sessionStorage","module","global","this","arguments","super"
        ]
    ]

    let contains: [Mode] = [
        // Однострочные комментарии
        Mode(scope: "comment", begin: "//", end: "\n", contains: []),
        Mode(scope: "comment", begin: "#", end: "\n", contains: []),
        // Многострочные комментарии
        Mode(scope: "comment", begin: "/\\*", end: "\\*/", contains: []),
        Mode(scope: "comment.doc", begin: "/\\*\\*", end: "\\*/", contains: []),
        Mode(scope: "function", begin: "\\bfunction\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "\\bclass\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        Mode(scope: "class", begin: "\\bextends\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),

        // Строки
        CommonModes.stringDouble,
        CommonModes.stringSingle,
        Mode(scope: "string", begin: "`", end: "`", contains: [
            // Подстановки внутри шаблонных строк
            Mode(scope: "subst", begin: "\\$\\{", end: "\\}", contains: [])
        ]),
    ]
}
