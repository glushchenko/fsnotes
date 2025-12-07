//
//  ErlangLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct ErlangLanguage: LanguageDefinition {
    let name = "Erlang"
    let aliases: [String]? = ["erlang", "erl"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // Control flow
            "after", "and", "andalso", "band", "begin", "bnot", "bor", "bsl", "bsr",
            "bxor", "case", "catch", "cond", "div", "end", "fun", "if", "let",
            "not", "of", "or", "orelse", "receive", "rem", "try", "when", "xor",
            // Module attributes
            "module", "export", "import", "compile", "vsn", "author", "copyright",
            "doc", "behaviour", "behavior", "record", "include", "include_lib",
            "define", "undef", "ifdef", "ifndef", "else", "endif", "error", "warning",
            // Special forms
            "query", "spec", "type", "opaque", "callback", "export_type"
        ],
        "literal": ["true", "false"],
        "built_in": [
            // BIFs (Built-In Functions)
            "abs", "adler32", "adler32_combine", "alive", "apply", "atom_to_binary",
            "atom_to_list", "binary_to_atom", "binary_to_existing_atom",
            "binary_to_list", "binary_to_term", "bit_size", "bitstring_to_list",
            "byte_size", "ceil", "check_process_code", "date", "delete_module",
            "demonitor", "disconnect_node", "display", "element", "erase", "error",
            "exit", "float", "float_to_list", "floor", "function_exported",
            "garbage_collect", "get", "get_keys", "group_leader", "halt", "hd",
            "integer_to_list", "iolist_size", "iolist_to_binary", "is_alive",
            "is_atom", "is_binary", "is_bitstring", "is_boolean", "is_builtin",
            "is_float", "is_function", "is_integer", "is_list", "is_map", "is_number",
            "is_pid", "is_port", "is_process_alive", "is_record", "is_reference",
            "is_tuple", "length", "link", "list_to_atom", "list_to_binary",
            "list_to_bitstring", "list_to_existing_atom", "list_to_float",
            "list_to_integer", "list_to_pid", "list_to_tuple", "load_module",
            "loaded", "localtime", "localtime_to_universaltime", "make_ref",
            "map_size", "max", "md5", "md5_final", "md5_init", "md5_update",
            "memory", "min", "module_loaded", "monitor", "monitor_node", "node",
            "nodes", "now", "open_port", "pid_to_list", "port_close", "port_command",
            "port_connect", "port_control", "port_info", "port_to_list",
            "process_display", "process_flag", "process_info", "purge_module", "put",
            "register", "registered", "round", "self", "send", "send_after",
            "send_nosuspend", "set_cookie", "setelement", "size", "spawn", "spawn_link",
            "spawn_monitor", "spawn_opt", "split_binary", "start_timer",
            "statistics", "system_flag", "system_info", "system_monitor",
            "system_profile", "term_to_binary", "throw", "time", "tl", "trace",
            "trace_delivered", "trace_info", "trace_pattern", "trunc", "tuple_size",
            "tuple_to_list", "unalias", "universaltime", "universaltime_to_localtime",
            "unlink", "unregister", "whereis",
            // Process dictionary
            "erase", "get", "get_keys", "put",
            // Ports
            "open_port", "port_call", "port_close", "port_command", "port_connect",
            "port_control", "port_info",
            // Lists module
            "all", "any", "append", "concat", "delete", "dropwhile", "duplicate",
            "filter", "filtermap", "flatlength", "flatmap", "flatten", "foldl",
            "foldr", "foreach", "keydelete", "keyfind", "keymap", "keymember",
            "keymerge", "keyreplace", "keysearch", "keysort", "keystore", "keytake",
            "last", "map", "mapfoldl", "mapfoldr", "max", "member", "merge",
            "min", "nth", "nthtail", "partition", "prefix", "reverse", "search",
            "seq", "sort", "split", "splitwith", "sublist", "subtract", "suffix",
            "sum", "takewhile", "ukeymerge", "ukeysort", "umerge", "uniq", "unzip",
            "unzip3", "usort", "zip", "zip3", "zipwith", "zipwith3",
            // String module
            "centre", "chars", "chr", "concat", "copies", "cspan", "equal", "join",
            "left", "len", "lexemes", "lowercase", "rchr", "replace", "right",
            "rstr", "slice", "span", "split", "str", "strip", "sub_string",
            "sub_word", "substr", "take", "tokens", "to_float", "to_integer",
            "to_lower", "to_upper", "trim", "uppercase", "words",
            // Binary module
            "at", "bin_to_list", "compile_pattern", "copy", "decode_unsigned",
            "encode_unsigned", "first", "last", "list_to_bin", "longest_common_prefix",
            "longest_common_suffix", "match", "matches", "part", "referenced_byte_size",
            "replace", "split",
            // Maps module
            "filter", "filtermap", "find", "fold", "foreach", "from_keys", "from_list",
            "get", "groups_from_list", "intersect", "intersect_with", "is_key",
            "iterator", "keys", "map", "merge", "merge_with", "new", "next", "put",
            "remove", "size", "take", "to_list", "update", "update_with", "values",
            "with", "without",
            // IO module
            "format", "fread", "fwrite", "get_chars", "get_line", "nl", "parse_erl_exprs",
            "parse_erl_form", "put_chars", "read", "scan_erl_exprs", "scan_erl_form",
            "write",
            // File module
            "close", "consult", "copy", "delete", "get_cwd", "list_dir", "make_dir",
            "open", "position", "pread", "pwrite", "read", "read_file", "read_file_info",
            "read_link", "read_link_info", "rename", "script", "set_cwd", "sync",
            "truncate", "write", "write_file", "write_file_info",
            // Process related
            "monitor", "demonitor", "link", "unlink", "spawn", "spawn_link",
            "spawn_monitor", "spawn_opt", "exit", "register", "unregister",
            "whereis", "send", "send_after", "send_nosuspend",
            // Ets (Erlang Term Storage)
            "all", "delete", "delete_all_objects", "delete_object", "file2tab",
            "first", "foldl", "foldr", "from_dets", "fun2ms", "give_away", "i",
            "info", "init_table", "insert", "insert_new", "is_compiled_ms", "last",
            "lookup", "lookup_element", "match", "match_delete", "match_object",
            "match_spec_compile", "match_spec_run", "member", "new", "next", "prev",
            "rename", "repair_continuation", "safe_fixtable", "select", "select_count",
            "select_delete", "select_replace", "select_reverse", "setopts", "slot",
            "tab2file", "tab2list", "tabfile_info", "table", "take", "test_ms",
            "to_dets", "update_counter", "update_element", "whereis",
            // Gen_server, gen_statem, supervisor behaviors
            "start", "start_link", "stop", "call", "cast", "reply", "abcast",
            "multi_call", "enter_loop", "init", "handle_call", "handle_cast",
            "handle_info", "terminate", "code_change", "format_status",
            // OTP application
            "ensure_all_started", "ensure_started", "get_all_env", "get_all_key",
            "get_application", "get_env", "get_key", "load", "loaded_applications",
            "set_env", "start", "start_type", "stop", "takeover", "unload",
            "unset_env", "which_applications",
            // Common records
            "state", "mod", "id"
        ]
    ]
    let contains: [Mode] = [
        // Comments
        Mode(scope: "comment", begin: "%", end: "\n"),
        
        // Module attributes
        Mode(scope: "meta", begin: "^-\\s*(?:module|export|import|compile|vsn|author|copyright|behaviour|behavior|record|include|include_lib|define|undef|ifdef|ifndef|else|endif|error|warning|spec|type|opaque|callback|export_type)\\b"),
        
        // Function definitions
        Mode(scope: "function", begin: "^([a-z][a-zA-Z0-9_@]*)\\s*\\("),
        
        // Atoms
        Mode(scope: "meta", begin: "'", end: "'"),
        Mode(scope: "meta", begin: "\\b[a-z][a-zA-Z0-9_@]*\\b(?!\\s*\\()"),
        
        // Variables (start with uppercase or underscore)
        Mode(scope: "meta", begin: "\\b[A-Z_][a-zA-Z0-9_@]*\\b"),
        
        // Macros
        Mode(scope: "meta", begin: "\\?[a-zA-Z][a-zA-Z0-9_@]*"),
        
        // Records
        Mode(scope: "class", begin: "#[a-z][a-zA-Z0-9_@]*"),
        
        // Strings
        CommonModes.stringDouble,
        
        // Binaries
        Mode(scope: "string", begin: "<<", end: ">>"),
        
        // Character literals
        Mode(scope: "string", begin: "\\$(?:[^\\\\]|\\\\(?:[bdefnrstv\\\\'\"]|[0-7]{1,3}|x[0-9a-fA-F]{2}|x\\{[0-9a-fA-F]+\\}|\\^[@-_]))"),
        
        // Numbers
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+(?:[eE][+-]?\\d+)?\\b"),
        // Based integers (e.g., 16#FF, 2#1010)
        Mode(scope: "number", begin: "\\b\\d+#[0-9a-zA-Z]+\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
    ]
}
