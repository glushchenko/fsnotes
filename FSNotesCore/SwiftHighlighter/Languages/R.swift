//
//  RLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct RLanguage: LanguageDefinition {
    let name = "R"
    let aliases: [String]? = ["r", "R"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "if", "else", "repeat", "while", "function", "for", "in", "next", "break",
            "return", "switch", "function", "library", "require", "source"
        ],
        "literal": [
            "TRUE", "FALSE", "NULL", "NA", "NA_integer_", "NA_real_", "NA_complex_",
            "NA_character_", "Inf", "NaN"
        ],
        "built_in": [
            // Base functions
            "c", "list", "vector", "matrix", "array", "data.frame", "factor",
            "length", "dim", "nrow", "ncol", "names", "colnames", "rownames",
            "class", "typeof", "mode", "str", "summary", "head", "tail", "View",
            // Math functions
            "abs", "sign", "sqrt", "floor", "ceiling", "trunc", "round", "signif",
            "exp", "log", "log10", "log2", "sin", "cos", "tan", "asin", "acos", "atan",
            "sinh", "cosh", "tanh", "min", "max", "sum", "prod", "mean", "median",
            "var", "sd", "range", "quantile", "cumsum", "cumprod", "cummin", "cummax",
            // Statistical functions
            "cor", "cov", "lm", "glm", "anova", "aov", "t.test", "chisq.test",
            "wilcox.test", "fisher.test", "shapiro.test", "ks.test", "var.test",
            "prop.test", "binom.test", "poisson.test",
            // Probability distributions
            "rnorm", "dnorm", "pnorm", "qnorm", "runif", "dunif", "punif", "qunif",
            "rbinom", "dbinom", "pbinom", "qbinom", "rpois", "dpois", "ppois", "qpois",
            "rexp", "dexp", "pexp", "qexp", "rgamma", "dgamma", "pgamma", "qgamma",
            "rbeta", "dbeta", "pbeta", "qbeta", "rt", "dt", "pt", "qt",
            "rchisq", "dchisq", "pchisq", "qchisq", "rf", "df", "pf", "qf",
            // Data manipulation
            "subset", "merge", "aggregate", "apply", "lapply", "sapply", "tapply",
            "mapply", "vapply", "replicate", "by", "split", "unsplit", "stack", "unstack",
            "reshape", "transform", "within", "attach", "detach", "with",
            // Logical functions
            "all", "any", "which", "which.max", "which.min", "ifelse",
            // Character functions
            "paste", "paste0", "cat", "print", "sprintf", "format", "toString",
            "substr", "substring", "strsplit", "grep", "grepl", "sub", "gsub",
            "regexpr", "gregexpr", "regmatches", "nchar", "tolower", "toupper",
            "chartr", "trimws",
            // Type conversion
            "as.numeric", "as.integer", "as.logical", "as.character", "as.factor",
            "as.Date", "as.POSIXct", "as.POSIXlt", "as.matrix", "as.data.frame",
            "as.list", "as.vector",
            // Type checking
            "is.numeric", "is.integer", "is.logical", "is.character", "is.factor",
            "is.na", "is.null", "is.nan", "is.infinite", "is.finite",
            "is.matrix", "is.data.frame", "is.list", "is.vector", "is.array",
            // File I/O
            "read.csv", "read.table", "read.delim", "readLines", "readRDS",
            "write.csv", "write.table", "writeLines", "saveRDS", "save", "load",
            "scan", "file", "open", "close", "readChar", "writeChar",
            // Data generation
            "seq", "seq_along", "seq_len", "rep", "rep_len", "gl", "expand.grid",
            "sample", "set.seed",
            // Sorting and ordering
            "sort", "order", "rank", "rev", "unique", "duplicated", "match",
            // Missing data
            "na.omit", "na.exclude", "na.fail", "na.pass", "complete.cases",
            // Graphics (base)
            "plot", "points", "lines", "abline", "polygon", "rect", "arrows",
            "hist", "barplot", "boxplot", "pie", "pairs", "matplot", "curve",
            "par", "layout", "mfrow", "mfcol", "legend", "title", "axis", "grid",
            "text", "mtext", "points", "segments", "polygon",
            // Graphics devices
            "pdf", "png", "jpeg", "tiff", "svg", "dev.new", "dev.off", "dev.cur",
            "dev.list", "dev.set",
            // Environment and system
            "ls", "rm", "exists", "get", "assign", "environment", "parent.frame",
            "sys.call", "sys.frame", "getwd", "setwd", "dir", "list.files",
            "file.exists", "file.info", "dir.create", "file.create", "file.remove",
            "Sys.time", "Sys.Date", "Sys.getenv", "Sys.setenv", "system", "system2",
            // Package management
            "install.packages", "library", "require", "loaded.packages",
            "search", "sessionInfo",
            // Debugging
            "debug", "undebug", "browser", "trace", "untrace", "traceback",
            "stop", "warning", "message", "stopifnot",
            // Apply family
            "apply", "lapply", "sapply", "vapply", "mapply", "tapply", "rapply",
            // Flow control helpers
            "tryCatch", "try", "withCallingHandlers", "suppressWarnings",
            "suppressMessages", "invisible",
            // Special operators
            "cbind", "rbind", "t", "solve", "det", "eigen", "svd", "qr",
            "chol", "diag", "crossprod", "tcrossprod", "outer",
            // Date/Time
            "Sys.time", "Sys.Date", "as.Date", "strptime", "strftime",
            "difftime", "ISOdate", "ISOdatetime",
            // Popular packages functions (commonly used)
            "ggplot", "aes", "geom_point", "geom_line", "geom_bar", "geom_histogram",
            "facet_wrap", "facet_grid", "theme", "labs", "scale_x_continuous",
            "dplyr", "select", "filter", "mutate", "arrange", "group_by", "summarize",
            "summarise", "left_join", "right_join", "inner_join", "full_join",
            "tidyr", "gather", "spread", "pivot_longer", "pivot_wider",
            "data.table", "fread", "fwrite"
        ]
    ]
    let contains: [Mode] = [
        // Roxygen comments (documentation)
        Mode(scope: "comment.doc", begin: "#'", end: "\n", contains: []),
        
        // Обычные комментарии
        Mode(scope: "comment", begin: "#", end: "\n", contains: []),
        
        // Определение функций
        Mode(scope: "function", begin: "\\b([a-zA-Z_][a-zA-Z0-9._]*)\\s*(?:=|<-)\\s*function"),
        
        // Вызов функций
        Mode(scope: "function", begin: "\\b[a-zA-Z_][a-zA-Z0-9._]*\\s*(?=\\()"),
        
        // Raw strings (R 4.0+)
        Mode(scope: "string", begin: "[rR]\"\\(", end: "\\)\"", contains: []),
        Mode(scope: "string", begin: "[rR]'\\(", end: "\\)'", contains: []),
        
        // Строки с двойными кавычками
        CommonModes.stringDouble,
        
        // Строки с одинарными кавычками
        CommonModes.stringSingle,
        
        // Backtick identifiers (нестандартные имена переменных)
        Mode(scope: "string", begin: "`", end: "`", contains: []),
        
        // Числа
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+[Ll]?\\b"),
        // Scientific notation
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*[eE][+-]?\\d+[Ll]?\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[Ll]?\\b"),
        // Integer with L suffix
        Mode(scope: "number", begin: "\\b\\d+[Ll]\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
        // Special numeric values
        Mode(scope: "number", begin: "\\b(?:Inf|NaN)\\b"),
    ]
}
