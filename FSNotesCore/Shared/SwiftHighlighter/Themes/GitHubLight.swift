//
//  GthubTheme.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 31.08.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import AppKit

struct GitHubLightTheme {
    static func make() -> HighlightStyle {
        var style = HighlightStyle()
        style.font = UserDefaultsManagement.codeFont
        style.foregroundColor = UserDefaultsManagement.fontColor
        style.styles = [
            // Базовые элементы
            "keyword": .init(color: NSColor(hex: "#333333"), traits: .bold),        // if, class, function, SELECT
            "string": .init(color: NSColor(hex: "#dd1144")),                       // "string", 'string'
            "number": .init(color: NSColor(hex: "#008080")),                       // 123, 3.14
            "comment": .init(color: NSColor(hex: "#999988"), traits: .italic),     // // comment, /* comment */
            "literal": .init(color: NSColor(hex: "#008080")),                      // true, false, null, TRUE, FALSE
            "variable": .init(color: NSColor(hex: "#008080")),                     // $var, @var, let name
            "modifier": .init(color: NSColor(hex: "#333333"), traits: .bold),      // public, private, static
            
            // Функции и классы
            "function": .init(color: NSColor(hex: "#990000"), traits: .bold),      // functionName(), COUNT()
            "class": .init(color: NSColor(hex: "#0066cc"), traits: .bold),         // ClassName, TableName, String, INT
            "params": .init(color: NSColor(hex: "#795da3")),                       // параметры функций
            
            // SQL специфичные
            "built_in": .init(color: NSColor(hex: "#0086b3"), traits: .bold),      // COUNT, SUM, NOW, Array
            "type": .init(color: NSColor(hex: "#458")),                            // VARCHAR, INT, String, Bool
            
            // Операторы и пунктуация
            "operator": .init(color: NSColor(hex: "#333333")),                     // +, -, =, !=, &&, ||
            "punctuation": .init(color: NSColor(hex: "#333333")),                  // (), [], {}, ,, ;
            
            // Мета-теги и специальные элементы
            "meta": .init(color: NSColor(hex: "#BAB8B8")),                         // <?php, ?>, HTML tags
            "subst": .init(color: NSColor(hex: "#333333")),                        // подстановки в строках
            
            // Дополнительные scope'ы для расширяемости
            "attribute": .init(color: NSColor(hex: "#0086b3")),                    // HTML/XML атрибуты
            "symbol": .init(color: NSColor(hex: "#990073")),                       // символы, константы
            "regexp": .init(color: NSColor(hex: "#009926")),                       // регулярные выражения
            "link": .init(color: NSColor(hex: "#0066cc")),                         // ссылки в Markdown
            "tag": .init(color: NSColor(hex: "#000080")),                          // HTML теги
            "name": .init(color: NSColor(hex: "#0066cc")),                         // имена тегов
            "quote": .init(color: NSColor(hex: "#dd1144")),                        // цитаты в Markdown
            "deletion": .init(color: NSColor(hex: "#bd2c00")),                     // удаленный текст в diff
            "addition": .init(color: NSColor(hex: "#55a532")),                     // добавленный текст в diff
            "strong": .init(color: NSColor(hex: "#333333"), traits: .bold),        // жирный текст в Markdown
            "emphasis": .init(color: NSColor(hex: "#333333"), traits: .italic)     // курсив в Markdown
        ]
        return style
    }
}
