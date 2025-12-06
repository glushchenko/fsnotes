//
//  AssemblyLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct AssemblyLanguage: LanguageDefinition {
    let name = "Assembly"
    let aliases: [String]? = ["asm", "asm86", "nasm", "masm", "gas"]
    let caseInsensitive = true
    let keywords: [String: [String]]? = [
        "keyword": [
            // Data movement
            "mov", "movb", "movw", "movl", "movq", "movsx", "movzx", "lea", "xchg",
            "push", "pop", "pusha", "popa", "pushad", "popad", "pushf", "popf",
            "pushfd", "popfd",
            // Arithmetic
            "add", "adc", "sub", "sbb", "mul", "imul", "div", "idiv", "inc", "dec",
            "neg", "cmp", "aaa", "aas", "aam", "aad", "daa", "das",
            // Logical
            "and", "or", "xor", "not", "test", "shl", "shr", "sal", "sar", "rol",
            "ror", "rcl", "rcr", "shld", "shrd",
            // Control flow
            "jmp", "je", "jz", "jne", "jnz", "jg", "jge", "jl", "jle", "ja", "jae",
            "jb", "jbe", "js", "jns", "jo", "jno", "jp", "jpe", "jnp", "jpo",
            "jcxz", "jecxz", "jrcxz",
            "call", "ret", "retn", "retf", "iret", "iretd", "iretq",
            "loop", "loope", "loopz", "loopne", "loopnz",
            // String operations
            "movs", "movsb", "movsw", "movsd", "movsq",
            "cmps", "cmpsb", "cmpsw", "cmpsd", "cmpsq",
            "scas", "scasb", "scasw", "scasd", "scasq",
            "lods", "lodsb", "lodsw", "lodsd", "lodsq",
            "stos", "stosb", "stosw", "stosd", "stosq",
            "rep", "repe", "repz", "repne", "repnz",
            // Stack frame
            "enter", "leave",
            // Flag operations
            "clc", "stc", "cmc", "cld", "std", "cli", "sti",
            "lahf", "sahf", "pushf", "popf", "pushfd", "popfd",
            // Processor control
            "nop", "hlt", "wait", "lock", "esc",
            // Set byte on condition
            "sete", "setz", "setne", "setnz", "setg", "setge", "setl", "setle",
            "seta", "setae", "setb", "setbe", "sets", "setns", "seto", "setno",
            "setp", "setpe", "setnp", "setpo",
            // Conditional move
            "cmove", "cmovz", "cmovne", "cmovnz", "cmovg", "cmovge", "cmovl", "cmovle",
            "cmova", "cmovae", "cmovb", "cmovbe", "cmovs", "cmovns", "cmovo", "cmovno",
            "cmovc", "cmovnc",
            // Bit manipulation
            "bt", "btc", "btr", "bts", "bsf", "bsr", "bswap",
            // I/O
            "in", "out", "ins", "insb", "insw", "insd", "outs", "outsb", "outsw", "outsd",
            // System
            "int", "into", "bound", "cpuid", "rdtsc", "rdmsr", "wrmsr",
            "lgdt", "sgdt", "lidt", "sidt", "lldt", "sldt", "ltr", "str",
            "lmsw", "smsw", "clts", "arpl", "lar", "lsl", "verr", "verw",
            "invd", "wbinvd", "invlpg", "invpcid",
            // x87 FPU
            "fld", "fst", "fstp", "fild", "fist", "fistp", "fbld", "fbstp",
            "fxch", "fcmove", "fcmovne", "fcmovb", "fcmovbe", "fcmovnb", "fcmovnbe",
            "fadd", "faddp", "fiadd", "fsub", "fsubp", "fisub", "fsubr", "fsubrp", "fisubr",
            "fmul", "fmulp", "fimul", "fdiv", "fdivp", "fidiv", "fdivr", "fdivrp", "fidivr",
            "fabs", "fchs", "fcom", "fcomp", "fcompp", "ficom", "ficomp", "fcomi", "fcomip",
            "fucomi", "fucomip", "ftst", "fxam", "fsqrt", "fsin", "fcos", "fsincos", "fptan",
            "fpatan", "f2xm1", "fyl2x", "fyl2xp1", "fldz", "fld1", "fldpi", "fldl2e", "fldl2t",
            "fldlg2", "fldln2", "finit", "fninit", "fclex", "fnclex", "fstcw", "fnstcw",
            "fldcw", "fstenv", "fnstenv", "fldenv", "fsave", "fnsave", "frstor", "fincstp",
            "fdecstp", "ffree", "ffreep", "fnop", "fwait",
            // SSE/AVX
            "movaps", "movups", "movss", "movsd", "movdqa", "movdqu", "movq",
            "addps", "addss", "subps", "subss", "mulps", "mulss", "divps", "divss",
            "sqrtps", "sqrtss", "maxps", "maxss", "minps", "minss",
            "andps", "andnps", "orps", "xorps", "cmpps", "cmpss",
            "vmovaps", "vmovups", "vaddps", "vsubps", "vmulps", "vdivps",
            // MMX
            "movd", "movq", "packsswb", "packssdw", "packuswb", "paddb", "paddw", "paddd",
            "paddsb", "paddsw", "paddusb", "paddusw", "pand", "pandn", "por", "pxor",
            "pcmpeqb", "pcmpeqw", "pcmpeqd", "pcmpgtb", "pcmpgtw", "pcmpgtd",
            "pmaddwd", "pmulhw", "pmullw", "psllw", "pslld", "psllq", "psraw", "psrad",
            "psrlw", "psrld", "psrlq", "psubb", "psubw", "psubd", "psubsb", "psubsw",
            "psubusb", "psubusw", "punpckhbw", "punpckhwd", "punpckhdq", "punpcklbw",
            "punpcklwd", "punpckldq", "emms"
        ],
        "literal": [],
        "built_in": [
            // Registers - 8-bit
            "al", "ah", "bl", "bh", "cl", "ch", "dl", "dh",
            "spl", "bpl", "sil", "dil",
            "r8b", "r9b", "r10b", "r11b", "r12b", "r13b", "r14b", "r15b",
            // Registers - 16-bit
            "ax", "bx", "cx", "dx", "si", "di", "bp", "sp",
            "r8w", "r9w", "r10w", "r11w", "r12w", "r13w", "r14w", "r15w",
            "ip", "cs", "ds", "es", "fs", "gs", "ss",
            // Registers - 32-bit
            "eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp",
            "r8d", "r9d", "r10d", "r11d", "r12d", "r13d", "r14d", "r15d",
            "eip", "eflags",
            // Registers - 64-bit
            "rax", "rbx", "rcx", "rdx", "rsi", "rdi", "rbp", "rsp",
            "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15",
            "rip", "rflags",
            // FPU registers
            "st0", "st1", "st2", "st3", "st4", "st5", "st6", "st7",
            "st",
            // MMX registers
            "mm0", "mm1", "mm2", "mm3", "mm4", "mm5", "mm6", "mm7",
            // XMM registers (SSE)
            "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7",
            "xmm8", "xmm9", "xmm10", "xmm11", "xmm12", "xmm13", "xmm14", "xmm15",
            // YMM registers (AVX)
            "ymm0", "ymm1", "ymm2", "ymm3", "ymm4", "ymm5", "ymm6", "ymm7",
            "ymm8", "ymm9", "ymm10", "ymm11", "ymm12", "ymm13", "ymm14", "ymm15",
            // ZMM registers (AVX-512)
            "zmm0", "zmm1", "zmm2", "zmm3", "zmm4", "zmm5", "zmm6", "zmm7",
            "zmm8", "zmm9", "zmm10", "zmm11", "zmm12", "zmm13", "zmm14", "zmm15",
            "zmm16", "zmm17", "zmm18", "zmm19", "zmm20", "zmm21", "zmm22", "zmm23",
            "zmm24", "zmm25", "zmm26", "zmm27", "zmm28", "zmm29", "zmm30", "zmm31",
            // Control registers
            "cr0", "cr2", "cr3", "cr4", "cr8",
            // Debug registers
            "dr0", "dr1", "dr2", "dr3", "dr6", "dr7",
            // Size directives
            "byte", "word", "dword", "qword", "tbyte", "oword", "yword", "zword",
            "ptr", "offset", "seg",
            // Data types
            "db", "dw", "dd", "dq", "dt", "do", "dy", "dz",
            "resb", "resw", "resd", "resq", "rest", "reso", "resy", "resz",
            // Directives
            "section", "segment", "global", "extern", "public", "extrn",
            "align", "alignb", "bits", "use16", "use32", "use64",
            "org", "times", "equ", "macro", "endm", "struc", "endstruc",
            "istruc", "iend", "end", "proc", "endp",
            // Special
            "short", "near", "far", "abs", "rel"
        ]
    ]
    let contains: [Mode] = [
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),
        
        Mode(scope: "comment", begin: ";", end: "\n"),
        Mode(scope: "comment", begin: "#", end: "\n"),
        Mode(scope: "comment", begin: "//", end: "\n"),
        Mode(scope: "comment", begin: "@", end: "\n"),
        
        Mode(scope: "meta", begin: "^\\s*%(?:define|undef|include|ifdef|ifndef|if|elif|else|endif|macro|endmacro|rep|endrep)\\b"),
        Mode(scope: "meta", begin: "^\\.(?:text|data|bss|section|global|extern|align|ascii|asciz|byte|word|long|quad)\\b"),
        Mode(scope: "meta", begin: "^\\s*\\.\\w+"),
        
        Mode(scope: "function", begin: "^[a-zA-Z_][a-zA-Z0-9_]*:"),
        Mode(scope: "function", begin: "^\\.[a-zA-Z_][a-zA-Z0-9_]*:"),
        
        Mode(scope: "function", begin: "^\\d+:"),
        
        CommonModes.stringDouble,
        CommonModes.stringSingle,
        
        Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)'"),
        
        // Binary
        Mode(scope: "number", begin: "\\b0[bB][01]+[hH]?\\b"),
        Mode(scope: "number", begin: "\\b[01]+[bB]\\b"),
        // Octal
        Mode(scope: "number", begin: "\\b0[oO][0-7]+\\b"),
        Mode(scope: "number", begin: "\\b[0-7]+[oOqQ]\\b"),
        // Hex
        Mode(scope: "number", begin: "\\b0[xX][0-9a-fA-F]+\\b"),
        Mode(scope: "number", begin: "\\b[0-9][0-9a-fA-F]*[hH]\\b"),
        Mode(scope: "number", begin: "\\$[0-9a-fA-F]+\\b"),
        // Decimal
        Mode(scope: "number", begin: "\\b\\d+[dD]?\\b"),
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+(?:[eE][+-]?\\d+)?\\b"),
        
        Mode(scope: "meta", begin: "\\[", end: "\\]"),
    ]
}
