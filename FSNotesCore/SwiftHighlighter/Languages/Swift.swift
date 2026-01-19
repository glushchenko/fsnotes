//  SwiftLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 31.08.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct SwiftLanguage: LanguageDefinition {
    let name = "Swift"
    let aliases: [String]? = ["swift"]
    let caseInsensitive = false

    let keywords: [String: [String]]? = [
        "keyword": [
            "class","struct","enum","protocol","extension","func","init","deinit", 
            "var","let","if","else","switch","case","default","for","while","repeat",
            "break","continue","return","throw","try","catch","guard","defer","import",
            "in","as","is","super","self","Type","where","associatedtype","subscript"
        ],
        "modifier": [
            "public","private","internal","fileprivate","open", 
            "static","final","override","lazy","weak","unowned",
            "required","convenience","mutating","nonmutating","throws","rethrows"
        ],
        "literal": ["true","false","nil","self","super"],
        "built_in": [
            "Array","Dictionary","Set","String","Character","Int","UInt","Double","Float", 
            "Bool","Optional","Result","Error","Any","Never","Void"
        ]
    ]

    let contains: [Mode] = [
        CommonModes.comment(begin: "//", end: "\n"),
        CommonModes.comment(begin: "/\\*", end: "\\*/"),

        CommonModes.stringDouble,
        CommonModes.number,

        Mode(
            scope: "variable",
            begin: "\\b(?:let|var)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        Mode(
            scope: "function",
            begin: "\\bfunc\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        Mode(
            scope: "function",
            begin: "\\binit\\s*(?:\\(|\\s)"
        ),

        Mode(
            scope: "function",
            begin: "\\bdeinit\\s*(?:\\{|\\s|$)"
        ),

        Mode(
            scope: "class",
            begin: "\\b(?:class|struct|enum|protocol|extension)\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        Mode(
            scope: "class",
            begin: ":\\s*([a-zA-Z_][a-zA-Z0-9_]*(?:\\s*,\\s*[a-zA-Z_][a-zA-Z0-9_]*)*)"
        ),

        Mode(
            scope: "class",
            begin: ":\\s*([a-zA-Z_][a-zA-Z0-9_]*(?:<[^>]*>)?(?:\\?|!)?)"
        ),

        Mode(
            scope: "class",
            begin: "\\bas\\s+([a-zA-Z_][a-zA-Z0-9_]*(?:<[^>]*>)?(?:\\?|!)?)"
        ),

        Mode(
            scope: "class",
            begin: "\\bis\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        )
    ]
}
