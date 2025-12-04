struct SQLLanguage: LanguageDefinition {
    let name = "SQL"
    let aliases: [String]? = ["sql", "mysql", "postgresql", "sqlite"]
    let caseInsensitive = true

    let keywords: [String: [String]]? = [
        "keyword": [
            // DDL (Data Definition Language)
            "CREATE", "ALTER", "DROP", "TRUNCATE", "RENAME",
            "ADD", "MODIFY", "CHANGE", "COLUMN", "TABLE", "VIEW", "INDEX", "DATABASE", "SCHEMA",
            
            // DML (Data Manipulation Language)
            "SELECT", "INSERT", "UPDATE", "DELETE", "REPLACE",
            "INTO", "VALUES", "SET",
            
            // DQL (Data Query Language)
            "FROM", "WHERE", "GROUP", "BY", "HAVING", "ORDER",
            "ASC", "DESC", "LIMIT", "OFFSET", "TOP",
            
            // Joins
            "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER", "CROSS",
            "ON", "USING",
            
            // Logical operators
            "AND", "OR", "NOT", "IN", "EXISTS", "BETWEEN", "LIKE",
            "IS", "NULL", "ISNULL",
            
            // Set operations
            "UNION", "INTERSECT", "EXCEPT", "MINUS",
            
            // Subqueries
            "ALL", "ANY", "SOME",
            
            // Constraints
            "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE",
            "CHECK", "DEFAULT", "AUTO_INCREMENT",
            
            // Transactions
            "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION", "SAVEPOINT",
            
            // Other
            "AS", "DISTINCT", "CASE", "WHEN", "THEN", "ELSE", "END",
            "IF", "ELSEIF", "ENDIF", "WHILE", "LOOP", "REPEAT",
            "DECLARE", "CURSOR", "FETCH", "CLOSE", "OPEN"
        ],
        
        "built_in": [
            // Aggregate functions
            "COUNT", "SUM", "AVG", "MIN", "MAX", "GROUP_CONCAT",
            "STDDEV", "VARIANCE",
            
            // String functions
            "CONCAT", "LENGTH", "SUBSTRING", "SUBSTR", "TRIM", "LTRIM", "RTRIM",
            "UPPER", "LOWER", "REPLACE", "REVERSE", "LEFT", "RIGHT",
            "CHARINDEX", "INSTR", "LOCATE", "POSITION", "ASCII", "CHAR",
            
            // Date/Time functions
            "NOW", "CURDATE", "CURTIME", "DATE", "TIME", "DATETIME",
            "TIMESTAMP", "YEAR", "MONTH", "DAY", "HOUR", "MINUTE", "SECOND",
            "DATEDIFF", "DATEADD", "DATE_FORMAT", "STR_TO_DATE",
            
            // Math functions
            "ABS", "CEIL", "CEILING", "FLOOR", "ROUND", "TRUNCATE",
            "MOD", "POWER", "SQRT", "RAND", "PI", "SIN", "COS", "TAN",
            
            // Conditional functions
            "IFNULL", "NULLIF", "COALESCE",
            
            // Conversion functions
            "CAST", "CONVERT", "FORMAT"
        ],
        
        "type": [
            // Numeric types
            "INT", "INTEGER", "SMALLINT", "TINYINT", "MEDIUMINT", "BIGINT",
            "DECIMAL", "NUMERIC", "FLOAT", "DOUBLE", "REAL", "BIT",
            "BOOLEAN", "BOOL", "SERIAL",
            
            // String types
            "CHAR", "VARCHAR", "TEXT", "TINYTEXT", "MEDIUMTEXT", "LONGTEXT",
            "BINARY", "VARBINARY", "BLOB", "TINYBLOB", "MEDIUMBLOB", "LONGBLOB",
            "ENUM", "SET",
            
            // Date/Time types
            "DATE", "TIME", "DATETIME", "TIMESTAMP", "YEAR",
            
            // JSON and other types
            "JSON", "UUID", "POINT", "GEOMETRY", "LINESTRING", "POLYGON"
        ],
        
        "literal": [
            "TRUE", "FALSE", "NULL", "UNKNOWN"
        ]
    ]

    let contains: [Mode] = [
        Mode(scope: "comment", begin: "--.*$"),
        Mode(scope: "comment", begin: "#.*$"),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)*'"),
        Mode(scope: "string", begin: "\"(?:[^\"\\\\]|\\\\.)*\""),
        Mode(scope: "number", begin: "\\b(?:0[xX][0-9a-fA-F]+|\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\b"),
        Mode(scope: "variable", begin: "@[a-zA-Z_][a-zA-Z0-9_]*\\b"),
        Mode(scope: "variable", begin: "@@[a-zA-Z_][a-zA-Z0-9_]*\\b"),
        Mode(scope: "variable", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*\\b"),
        Mode(scope: "class", begin: "`([a-zA-Z_][a-zA-Z0-9_]*)`"),
        Mode(scope: "function", begin: "\\b([a-zA-Z_][a-zA-Z0-9_]*)(?=\\s*\\()"),
        Mode(scope: "operator", begin: "\\+|\\-|\\*|/|%|=|!=|<>|<=|>=|<|>|\\|\\||&&")
    ]
}
