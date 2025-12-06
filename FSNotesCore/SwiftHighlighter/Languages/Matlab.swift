//
//  MatlabLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct MatlabLanguage: LanguageDefinition {
    let name = "MATLAB"
    let aliases: [String]? = ["matlab", "m"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            "break", "case", "catch", "classdef", "continue", "else", "elseif", "end",
            "for", "function", "global", "if", "otherwise", "parfor", "persistent",
            "return", "spmd", "switch", "try", "while",
            // Additional keywords
            "arguments", "properties", "methods", "events", "enumeration"
        ],
        "literal": ["true", "false", "inf", "Inf", "nan", "NaN", "eps", "pi"],
        "built_in": [
            // Basic functions
            "abs", "acos", "acosh", "acot", "acoth", "acsc", "acsch", "angle",
            "asec", "asech", "asin", "asinh", "atan", "atan2", "atanh", "ceil",
            "complex", "conj", "cos", "cosh", "cot", "coth", "csc", "csch",
            "exp", "fix", "floor", "imag", "isreal", "log", "log10", "log2",
            "real", "round", "sec", "sech", "sign", "sin", "sinh", "sqrt",
            "tan", "tanh", "mod", "rem", "gcd", "lcm",
            // Matrix operations
            "det", "eig", "inv", "pinv", "rank", "trace", "norm", "cond",
            "rcond", "expm", "logm", "sqrtm", "chol", "lu", "qr", "svd",
            "schur", "hess", "balance", "kron", "cross", "dot",
            // Array operations
            "size", "length", "numel", "ndims", "isempty", "isequal", "isequaln",
            "zeros", "ones", "eye", "rand", "randn", "randi", "true", "false",
            "diag", "tril", "triu", "reshape", "repmat", "cat", "horzcat", "vertcat",
            "transpose", "ctranspose", "permute", "ipermute", "circshift", "flip",
            "fliplr", "flipud", "rot90", "squeeze", "shiftdim",
            // Indexing and sorting
            "find", "sort", "sortrows", "issorted", "unique", "union", "intersect",
            "setdiff", "setxor", "ismember", "max", "min", "sum", "prod", "mean",
            "median", "mode", "std", "var", "cov", "corrcoef",
            // Logical operations
            "all", "any", "and", "or", "not", "xor", "isnan", "isinf", "isfinite",
            "logical", "bitand", "bitor", "bitxor", "bitcmp", "bitshift", "bitget",
            "bitset",
            // String operations
            "char", "string", "strcat", "strcmp", "strcmpi", "strncmp", "strncmpi",
            "strfind", "strrep", "strsplit", "strjoin", "strip", "lower", "upper",
            "sprintf", "fprintf", "sscanf", "num2str", "str2num", "str2double",
            "int2str", "mat2str", "blanks", "deblank", "strtrim", "pad", "strip",
            // Type conversion and testing
            "double", "single", "int8", "int16", "int32", "int64", "uint8", "uint16",
            "uint32", "uint64", "cast", "typecast", "class", "isa", "isnumeric",
            "ischar", "isstring", "islogical", "iscell", "isstruct", "istable",
            "ismatrix", "isvector", "isscalar", "isrow", "iscolumn",
            // Cell and structure arrays
            "cell", "cell2mat", "cellstr", "num2cell", "mat2cell", "cellfun",
            "celldisp", "struct", "struct2cell", "fieldnames", "isfield",
            "rmfield", "orderfields", "structfun",
            // File I/O
            "load", "save", "importdata", "readmatrix", "readtable", "readcell",
            "writematrix", "writetable", "writecell", "xlsread", "xlswrite",
            "csvread", "csvwrite", "dlmread", "dlmwrite", "textscan", "fopen",
            "fclose", "fread", "fwrite", "fprintf", "fscanf", "fgetl", "fgets",
            "frewind", "fseek", "ftell", "feof", "ferror",
            // Plotting
            "plot", "plot3", "scatter", "scatter3", "bar", "barh", "histogram",
            "pie", "pie3", "surf", "mesh", "contour", "contourf", "imagesc",
            "image", "imshow", "pcolor", "quiver", "quiver3", "streamline",
            "fill", "fill3", "area", "stem", "stem3", "stairs", "errorbar",
            "polarplot", "compass", "feather", "comet", "comet3",
            // Plot annotation and formatting
            "title", "xlabel", "ylabel", "zlabel", "legend", "colorbar", "colormap",
            "grid", "box", "axis", "xlim", "ylim", "zlim", "hold", "subplot",
            "figure", "clf", "cla", "close", "axes", "gca", "gcf", "set", "get",
            "text", "annotation", "line", "patch", "rectangle", "saveas", "print",
            // Statistical functions
            "histcounts", "histogram", "cumsum", "cumprod", "cummax", "cummin",
            "movsum", "movmean", "movmedian", "movmax", "movmin", "movstd", "movvar",
            "diff", "gradient", "del2", "trapz", "cumtrapz",
            // Interpolation and curve fitting
            "interp1", "interp2", "interp3", "interpn", "griddedInterpolant",
            "scatteredInterpolant", "polyfit", "polyval", "polyvalm", "polyder",
            "polyint", "spline", "pchip", "makima",
            // Linear algebra
            "linsolve", "mldivide", "mrdivide", "lsqr", "gmres", "bicg", "cgs",
            "minres", "pcg", "symmlq", "tfqmr", "null", "orth", "rref", "subspace",
            // Optimization
            "fminbnd", "fminsearch", "fzero", "fsolve", "lsqnonlin", "lsqcurvefit",
            // ODE solvers
            "ode45", "ode23", "ode113", "ode15s", "ode23s", "ode23t", "ode23tb",
            "ode15i", "deval", "odeset", "odeget",
            // FFT and signal processing
            "fft", "fft2", "fftn", "ifft", "ifft2", "ifftn", "fftshift", "ifftshift",
            "conv", "conv2", "filter", "deconv", "xcorr", "xcorr2", "corrcoef",
            // Random number generation
            "rand", "randn", "randi", "randperm", "rng",
            // System and environment
            "pwd", "cd", "dir", "ls", "mkdir", "rmdir", "delete", "copyfile",
            "movefile", "exist", "which", "what", "path", "addpath", "rmpath",
            "matlabroot", "version", "computer", "ispc", "isunix", "ismac",
            // Program control
            "input", "disp", "display", "warning", "error", "assert", "pause",
            "keyboard", "dbstop", "dbclear", "dbcont", "dbstep", "dbquit",
            "diary", "echo", "eval", "evalc", "evalin", "assignin", "run",
            // Time and date
            "now", "date", "datenum", "datestr", "datevec", "datetime", "duration",
            "tic", "toc", "cputime", "clock", "etime",
            // Table operations
            "table", "array2table", "cell2table", "struct2table", "table2array",
            "table2cell", "table2struct", "readtable", "writetable", "join",
            "innerjoin", "outerjoin", "sortrows", "unique", "ismember",
            // Miscellaneous
            "nargin", "nargout", "varargin", "varargout", "inputname", "mfilename",
            "clc", "clear", "who", "whos", "help", "doc", "lookfor", "demo",
            "format", "beep", "profile", "bench", "timeit", "tic", "toc"
        ]
    ]
    let contains: [Mode] = [
        // Block comments
        Mode(scope: "comment", begin: "%\\{", end: "%\\}"),
        
        // Line comments
        Mode(scope: "comment", begin: "%", end: "\n"),
        
        // Function definitions
        Mode(scope: "function", begin: "\\bfunction\\s+(?:\\[?[^\\]]*\\]?\\s*=\\s*)?([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Class definitions
        Mode(scope: "class", begin: "\\bclassdef\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // String with single quotes (MATLAB standard)
        CommonModes.stringSingle,
        
        // String with double quotes (newer MATLAB versions)
        CommonModes.stringDouble,
        
        // Transpose operator (should not be confused with string end)
        Mode(scope: "keyword", begin: "\\.?'(?!')"),
        
        // Numbers
        // Complex numbers with i or j suffix
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*[eE][+-]?\\d+[ij]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+[ij]?\\b"),
        Mode(scope: "number", begin: "\\b\\d+[ij]\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+\\b"),
        // Binary
        Mode(scope: "number", begin: "\\b0[bB][01]+\\b"),
        // Regular numbers
        Mode(scope: "number", begin: "\\b\\d+\\.?\\d*[eE][+-]?\\d+\\b"),
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+\\b"),
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
