//
//  BashLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct BashLanguage: LanguageDefinition {
    let name = "Bash"
    let aliases: [String]? = ["bash", "sh", "shell", "zsh"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // Control flow
            "if", "then", "else", "elif", "fi", "case", "esac", "for", "select",
            "while", "until", "do", "done", "in", "function", "time",
            // Declarations
            "declare", "typeset", "local", "export", "readonly", "unset",
            // Built-in commands
            "break", "continue", "return", "exit", "shift", "eval", "exec",
            "source", ".", "trap", "wait", "jobs", "bg", "fg", "disown",
            "suspend", "alias", "unalias", "set", "unset", "shopt",
            "enable", "command", "builtin", "caller", "true", "false",
            // Test commands
            "test", "[", "[[",
            // Compound commands
            "{", "}", "((", "))", "[[", "]]"
        ],
        "literal": ["true", "false"],
        "built_in": [
            // File operations
            "cat", "cp", "mv", "rm", "rmdir", "mkdir", "touch", "ln", "chmod",
            "chown", "chgrp", "ls", "pwd", "cd", "pushd", "popd", "dirs",
            "find", "locate", "which", "whereis", "file", "stat", "du", "df",
            "mount", "umount", "dd", "tar", "gzip", "gunzip", "bzip2", "bunzip2",
            "zip", "unzip", "compress", "uncompress", "rsync", "scp", "sftp",
            // Text processing
            "echo", "printf", "read", "cat", "head", "tail", "less", "more",
            "grep", "egrep", "fgrep", "sed", "awk", "cut", "paste", "join",
            "sort", "uniq", "wc", "tr", "expand", "unexpand", "fold", "fmt",
            "nl", "pr", "tee", "split", "csplit", "diff", "patch", "cmp",
            "comm", "column", "iconv", "dos2unix", "unix2dos",
            // Process management
            "ps", "top", "htop", "kill", "killall", "pkill", "pgrep", "pidof",
            "nice", "renice", "nohup", "screen", "tmux", "at", "batch", "cron",
            "crontab", "sleep", "timeout", "watch", "xargs",
            // System information
            "uname", "hostname", "uptime", "who", "whoami", "id", "groups",
            "users", "last", "lastlog", "w", "finger", "date", "cal", "time",
            "timedatectl", "localectl", "hostnamectl",
            // Network
            "ping", "traceroute", "netstat", "ss", "ip", "ifconfig", "route",
            "arp", "dig", "nslookup", "host", "wget", "curl", "nc", "netcat",
            "telnet", "ftp", "ssh", "scp", "rsync", "nmap", "tcpdump",
            // User management
            "useradd", "usermod", "userdel", "groupadd", "groupmod", "groupdel",
            "passwd", "chpasswd", "su", "sudo", "visudo",
            // Package management
            "apt", "apt-get", "aptitude", "dpkg", "yum", "dnf", "rpm", "zypper",
            "pacman", "brew", "snap", "flatpak",
            // System management
            "systemctl", "service", "journalctl", "dmesg", "shutdown", "reboot",
            "poweroff", "halt", "init", "telinit",
            // Shell built-ins
            "alias", "bg", "bind", "builtin", "caller", "cd", "command",
            "compgen", "complete", "compopt", "continue", "declare", "dirs",
            "disown", "echo", "enable", "eval", "exec", "exit", "export",
            "false", "fc", "fg", "getopts", "hash", "help", "history", "jobs",
            "kill", "let", "local", "logout", "mapfile", "popd", "printf",
            "pushd", "pwd", "read", "readarray", "readonly", "return", "set",
            "shift", "shopt", "source", "suspend", "test", "times", "trap",
            "true", "type", "typeset", "ulimit", "umask", "unalias", "unset",
            "wait",
            // Common utilities
            "basename", "dirname", "expr", "bc", "dc", "seq", "yes", "tty",
            "stty", "clear", "reset", "script", "rev", "factor", "env",
            "printenv", "getopt", "getopts", "mktemp", "mkfifo", "tput",
            // Archiving
            "tar", "cpio", "zip", "unzip", "gzip", "gunzip", "bzip2", "bunzip2",
            "xz", "unxz", "7z", "rar", "unrar",
            // Disk operations
            "fdisk", "parted", "mkfs", "fsck", "tune2fs", "resize2fs", "blkid",
            "lsblk", "hdparm", "smartctl",
            // Variables
            "PATH", "HOME", "USER", "SHELL", "PWD", "OLDPWD", "TMPDIR", "LANG",
            "LC_ALL", "TERM", "EDITOR", "VISUAL", "PAGER", "PS1", "PS2", "PS3",
            "PS4", "IFS", "RANDOM", "SECONDS", "LINENO", "BASHPID", "BASH_VERSION",
            "HOSTNAME", "UID", "EUID", "GROUPS", "PPID", "SHLVL", "BASH_SUBSHELL",
            // Special parameters
            "$@", "$*", "$#", "$$", "$!", "$?", "$-", "$_", "$0",
            // Test operators
            "-e", "-f", "-d", "-L", "-h", "-b", "-c", "-p", "-S", "-t",
            "-r", "-w", "-x", "-s", "-u", "-g", "-k", "-O", "-G", "-N",
            "-nt", "-ot", "-ef", "-z", "-n", "=", "!=", "==", "-eq", "-ne",
            "-lt", "-le", "-gt", "-ge", "&&", "||", "!"
        ]
    ]
    let contains: [Mode] = [
        // Shebang
        Mode(scope: "comment", begin: "^#!", end: "\n", contains: []),
        Mode(scope: "comment", begin: "#", end: "\n", contains: []),
        
        // Heredoc
        Mode(scope: "string", begin: "<<-?\\s*(['\"]?)([a-zA-Z_][a-zA-Z0-9_]*)\\1", end: "^\\2$", contains: []),
        
        // Variables
        Mode(scope: "meta", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*"),
        Mode(scope: "meta", begin: "\\$\\{[^}]+\\}"),
        Mode(scope: "meta", begin: "\\$\\([^)]+\\)"),
        Mode(scope: "meta", begin: "\\$\\(\\([^)]+\\)\\)"),
        
        // Special
        Mode(scope: "meta", begin: "\\$[0-9@*#?$!_-]"),
        
        // Command substitution (backticks)
        //Mode(scope: "string", begin: "`", end: "`", contains: []),
        
        // Strings with double quotes (allows variable expansion)
        Mode(scope: "string", begin: "\"", end: "\"", contains: [
            Mode(scope: "subst", begin: "\\$[a-zA-Z_][a-zA-Z0-9_]*"),
            Mode(scope: "subst", begin: "\\$\\{[^}]+\\}"),
            Mode(scope: "subst", begin: "\\$\\([^)]+\\)")
        ]),
        
        // Strings with single quotes (no expansion)
        CommonModes.stringSingle,
        
        // ANSI-C quoting
        Mode(scope: "string", begin: "\\$'", end: "'", contains: []),
        
        // Functions
        Mode(scope: "function", begin: "^\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(\\s*\\)"),
        Mode(scope: "function", begin: "\\bfunction\\s+([a-zA-Z_][a-zA-Z0-9_]*)"),
        
        // Numbers
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+\\b"),
        Mode(scope: "number", begin: "\\b0[0-7]+\\b"),
        Mode(scope: "number", begin: "\\b[0-9]+\\b"),
        
        // Redirection operators
        Mode(scope: "keyword", begin: "[0-9]*(?:>>|>|<<|<|&>|&>>|<&|>&|<>)"),
        
        // Pipe
        Mode(scope: "keyword", begin: "\\|\\|?|&&?|;|&"),
    ]
}
