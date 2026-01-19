//
//  PerlLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct PerlLanguage: LanguageDefinition {
    let name = "Perl"
    let aliases: [String]? = ["perl", "pl", "pm"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // Control flow
            "if", "elsif", "else", "unless", "given", "when", "default",
            "while", "until", "for", "foreach", "do", "continue",
            // Jumps
            "last", "next", "redo", "goto",
            // Declarations
            "sub", "my", "our", "local", "state",
            // Package/Module
            "package", "use", "require", "no",
            // Special
            "BEGIN", "END", "CHECK", "INIT", "UNITCHECK",
            // References
            "ref", "bless",
            // Operators
            "and", "or", "not", "xor", "eq", "ne", "lt", "gt", "le", "ge", "cmp",
            "x", "xx",
            // Others
            "return", "undef", "defined", "exists", "delete", "eval", "exec",
            "die", "warn", "exit", "fork", "wait", "waitpid", "system", "exec",
            "caller", "wantarray", "prototype", "tied", "untie",
            // File tests
            "-r", "-w", "-x", "-o", "-R", "-W", "-X", "-O", "-e", "-z", "-s",
            "-f", "-d", "-l", "-p", "-S", "-b", "-c", "-t", "-u", "-g", "-k",
            "-T", "-B", "-M", "-A", "-C",
            // Special keywords
            "__FILE__", "__LINE__", "__PACKAGE__", "__SUB__", "__END__", "__DATA__",
            // Try-catch (Perl 5.34+)
            "try", "catch", "finally"
        ],
        "literal": ["undef"],
        "built_in": [
            // String functions
            "chomp", "chop", "chr", "crypt", "fc", "hex", "index", "lc", "lcfirst",
            "length", "oct", "ord", "pack", "reverse", "rindex", "sprintf", "substr",
            "tr", "uc", "ucfirst", "y", "quotemeta", "split", "join",
            // Array functions
            "pop", "push", "shift", "unshift", "splice", "grep", "map", "sort",
            "reverse", "keys", "values", "each", "delete", "exists",
            // Hash functions
            "keys", "values", "each", "exists", "delete",
            // List functions
            "grep", "map", "sort", "reverse",
            // Regex functions
            "m", "qr", "s", "tr", "y", "match", "split", "pos", "study",
            // I/O functions
            "open", "close", "opendir", "closedir", "chdir", "read", "write",
            "print", "printf", "say", "readline", "readdir", "rewinddir", "seekdir",
            "telldir", "eof", "fileno", "flock", "select", "getc", "binmode",
            "sysopen", "sysread", "syswrite", "sysseek", "truncate", "stat", "lstat",
            "readlink", "symlink", "link", "unlink", "rename", "chmod", "chown",
            "chroot", "umask", "utime",
            // File test operators (as functions)
            "abs", "accept", "alarm", "atan2", "bind", "binmode", "bless", "caller",
            "chdir", "chmod", "chomp", "chop", "chown", "chr", "chroot", "close",
            "closedir", "connect", "cos", "crypt", "dbmclose", "dbmopen", "defined",
            "delete", "die", "do", "dump", "each", "endgrent", "endhostent",
            "endnetent", "endprotoent", "endpwent", "endservent", "eof", "eval",
            "exec", "exists", "exit", "exp", "fcntl", "fileno", "flock", "fork",
            "format", "formline", "getc", "getgrent", "getgrgid", "getgrnam",
            "gethostbyaddr", "gethostbyname", "gethostent", "getlogin", "getnetbyaddr",
            "getnetbyname", "getnetent", "getpeername", "getpgrp", "getppid",
            "getpriority", "getprotobyname", "getprotobynumber", "getprotoent",
            "getpwent", "getpwnam", "getpwuid", "getservbyname", "getservbyport",
            "getservent", "getsockname", "getsockopt", "glob", "gmtime", "goto",
            "grep", "hex", "import", "index", "int", "ioctl", "join", "keys", "kill",
            "last", "lc", "lcfirst", "length", "link", "listen", "local", "localtime",
            "lock", "log", "lstat", "map", "mkdir", "msgctl", "msgget", "msgrcv",
            "msgsnd", "my", "next", "no", "oct", "open", "opendir", "ord", "our",
            "pack", "package", "pipe", "pop", "pos", "print", "printf", "prototype",
            "push", "quotemeta", "rand", "read", "readdir", "readline", "readlink",
            "readpipe", "recv", "redo", "ref", "rename", "require", "reset", "return",
            "reverse", "rewinddir", "rindex", "rmdir", "say", "scalar", "seek",
            "seekdir", "select", "semctl", "semget", "semop", "send", "setgrent",
            "sethostent", "setnetent", "setpgrp", "setpriority", "setprotoent",
            "setpwent", "setservent", "setsockopt", "shift", "shmctl", "shmget",
            "shmread", "shmwrite", "shutdown", "sin", "sleep", "socket", "socketpair",
            "sort", "splice", "split", "sprintf", "sqrt", "srand", "stat", "state",
            "study", "sub", "substr", "symlink", "syscall", "sysopen", "sysread",
            "sysseek", "system", "syswrite", "tell", "telldir", "tie", "tied", "time",
            "times", "tr", "truncate", "uc", "ucfirst", "umask", "undef", "unlink",
            "unpack", "unshift", "untie", "use", "utime", "values", "vec", "wait",
            "waitpid", "wantarray", "warn", "write",
            // Special variables
            "$_", "@_", "$!", "$@", "$$", "$.", "$,", "$\\", "$\"", "$;", "$#",
            "$%", "$=", "$-", "$~", "$^", "$:", "$?", "$0", "$ARGV",
            "$a", "$b", "%ENV", "@ARGV", "@INC", "%INC", "%SIG", "$STDIN",
            "$STDOUT", "$STDERR", "$^O", "$^X", "$]", "$^V",
            // Pragmas
            "strict", "warnings", "utf8", "vars", "subs", "constant", "integer",
            "locale", "bytes", "open", "less", "feature", "experimental",
            "autodie", "autouse", "base", "bigint", "bignum", "bigrat", "blib",
            "diagnostics", "encoding", "fields", "filetest", "if", "lib", "mro",
            "ops", "overload", "overloading", "parent", "re", "sigtrap", "sort",
            "threads", "vmsish",
            // Common modules
            "Carp", "Data::Dumper", "Exporter", "File::Basename", "File::Copy",
            "File::Find", "File::Path", "File::Spec", "Getopt::Long", "Getopt::Std",
            "IO::File", "IO::Handle", "IO::Socket", "List::Util", "POSIX",
            "Scalar::Util", "Storable", "Time::HiRes", "Time::Local",
            // Object-oriented
            "bless", "DESTROY", "AUTOLOAD", "can", "isa", "VERSION",
            // Modern Perl features
            "state", "say", "given", "when", "default", "break", "__SUB__"
        ]
    ]
    let contains: [Mode] = [
        // POD (Plain Old Documentation)
        Mode(scope: "comment.doc", begin: "^=\\w+", end: "^=cut"),
        
        // Comments
        Mode(scope: "comment", begin: "#", end: "\n"),
        
        // Shebang
        Mode(scope: "comment", begin: "^#!", end: "\n"),
        
        // Subroutine definitions
        Mode(scope: "function", begin: "\\bsub\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Package declaration
        Mode(scope: "class", begin: "\\bpackage\\s+([a-zA-Z_][a-zA-Z0-9_:]*)"),
        
        // Regular expressions (with various delimiters)
        // m// or //
        Mode(scope: "string", begin: "\\b(?:m|qr)/", end: "/[gimosxaludn]*"),
        // m{}
        Mode(scope: "string", begin: "\\b(?:m|qr)\\{", end: "\\}[gimosxaludn]*"),
        // m[]
        Mode(scope: "string", begin: "\\b(?:m|qr)\\[", end: "\\][gimosxaludn]*"),
        // m()
        Mode(scope: "string", begin: "\\b(?:m|qr)\\(", end: "\\)[gimosxaludn]*"),
        // Bare //
        Mode(scope: "string", begin: "/(?![*/])", end: "/[gimosxaludn]*"),
        
        // Substitution s///
        Mode(scope: "string", begin: "\\bs/", end: "/[gimosxaludn]*"),
        Mode(scope: "string", begin: "\\bs\\{", end: "\\}[gimosxaludn]*"),
        Mode(scope: "string", begin: "\\bs\\[", end: "\\][gimosxaludn]*"),
        Mode(scope: "string", begin: "\\bs\\(", end: "\\)[gimosxaludn]*"),
        
        // Transliteration tr/// or y///
        Mode(scope: "string", begin: "\\b(?:tr|y)/", end: "/[cdsr]*"),
        
        // Quote-like operators
        // q{} qq{} qw{} qx{}
        Mode(scope: "string", begin: "\\bqq?\\{", end: "\\}"),
        Mode(scope: "string", begin: "\\bqq?\\[", end: "\\]"),
        Mode(scope: "string", begin: "\\bqq?\\(", end: "\\)"),
        Mode(scope: "string", begin: "\\bqq?/", end: "/"),
        Mode(scope: "string", begin: "\\bqw\\{", end: "\\}"),
        Mode(scope: "string", begin: "\\bqw\\[", end: "\\]"),
        Mode(scope: "string", begin: "\\bqw\\(", end: "\\)"),
        Mode(scope: "string", begin: "\\bqx\\{", end: "\\}"),
        
        // Here-docs
        Mode(scope: "string", begin: "<<['\"]?([A-Z_][A-Z0-9_]*)['\"]?", end: "^\\1$"),
        Mode(scope: "string", begin: "<<~['\"]?([A-Z_][A-Z0-9_]*)['\"]?", end: "^\\s*\\1$"),
        
        // Variables
        Mode(scope: "meta", begin: "[$@%](?:[a-zA-Z_][a-zA-Z0-9_]*|\\{[^}]+\\}|\\^[A-Z]|[0-9]+|[!@#$%^&*()_+=\\[\\]{}|;:,.<>?/~`-])"),
        
        // Typeglobs
        Mode(scope: "meta", begin: "\\*[a-zA-Z_][a-zA-Z0-9_]*"),
        
        // Double-quoted strings (with interpolation)
        Mode(scope: "string", begin: "\"", end: "\""),
        
        // Single-quoted strings (no interpolation)
        CommonModes.stringSingle,
        
        // Backtick strings (command execution)
        Mode(scope: "string", begin: "`", end: "`"),
        
        // Numbers
        // Binary (0b)
        Mode(scope: "number", begin: "\\b0[bB][01_]+\\b"),
        // Octal (0 or 0o)
        Mode(scope: "number", begin: "\\b0[oO]?[0-7_]+\\b"),
        // Hex (0x)
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F_]+\\b"),
        // Float with exponent
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\.\\d[0-9_]*(?:[eE][+-]?\\d[0-9_]*)?\\b"),
        Mode(scope: "number", begin: "\\b\\d[0-9_]*[eE][+-]?\\d[0-9_]*\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\.\\d[0-9_]*\\b"),
        // Integer with underscores (version numbers)
        Mode(scope: "number", begin: "\\b\\d[0-9_]*\\b"),
        // Version strings (v5.10.1)
        Mode(scope: "number", begin: "\\bv\\d+(?:\\.\\d+)*\\b"),
    ]
}
