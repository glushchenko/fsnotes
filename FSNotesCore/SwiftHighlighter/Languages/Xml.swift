//
//  XmlLanguage.swift
//  FSNotes
//

struct XmlLanguage: LanguageDefinition {
    let name = "XML"
    let aliases: [String]? = ["xml", "xsd", "xsl", "xslt", "svg", "plist"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = nil

    let contains: [Mode] = [
        Mode(scope: "comment", begin: "<!--", end: "-->"),
        Mode(scope: "meta", begin: "<\\?xml", end: "\\?>"),
        Mode(scope: "meta", begin: "<\\?", end: "\\?>"),
        Mode(scope: "meta", begin: "<!DOCTYPE", end: ">"),
        Mode(scope: "string", begin: "<!\\[CDATA\\[", end: "\\]\\]>"),

        Mode(scope: "tag", begin: "</?[A-Za-z_][A-Za-z0-9_.:-]*"),
        Mode(scope: "attribute", begin: "\\b[A-Za-z_][A-Za-z0-9_.:-]*(?=\\s*=)"),
        Mode(scope: "string", begin: "=\\s*\"", end: "\""),
        Mode(scope: "string", begin: "=\\s*'", end: "'"),
        Mode(scope: "string", begin: "&(?:[A-Za-z][A-Za-z0-9]+|#[0-9]+|#x[0-9A-Fa-f]+);"),
        Mode(scope: "tag", begin: "/?>")
    ]
}
