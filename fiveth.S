#if ! (__riscv_xlen == 32 || __riscv_xlen == 64)
# error "Sanity check: __riscv_xlen should be 32 or 64"
#endif

#if __riscv_xlen == 32

#define NATIVE 4
#define LGNATIVE 2
#define ln lw
#define sn sw
#define nbyte .4byte

#else // __riscv_xlen == 64

#define NATIVE 8
#define LGNATIVE 3
#define ln ld
#define sn sd
#define nbyte .8byte

#endif

#define s_dsp s0
#define s_ip s1
#define s_rsp s2
#define s_rfp s3

// Stack alignment
#define ALIGN(offset) (((offset) + 0xf) & ~0xf)

    .macro func name
        .p2align 1
        .type \name, @function
\name:
    .endm

    .macro endfunc name
        .size \name, . - \name
    .endm

    .macro go
        ln a0, (s_ip)
        ln a0, (a0)
        jr a0
    .endm

    .macro next
        addi s_ip, s_ip, NATIVE
        go
    .endm

#define o_code (0 * NATIVE)
#define o_link (1 * NATIVE)
#define o_name (2 * NATIVE)
#define o_namelen (3 * NATIVE)
#define o_payload (4 * NATIVE)

    .section .text

func _code_runconst
    ln a0, (s_ip)
    ln a0, o_payload(a0)
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    next
endfunc _code_runconst

    .macro enter_frame
    sn s_rfp, (0 * NATIVE)(s_rsp)
    sn s_ip, (1 * NATIVE)(s_rsp)
    addi s_rsp, s_rsp, 2 * NATIVE
    mv s_rfp, s_rsp
    .endm

func _code_rundef
    addi s_ip, s_ip, NATIVE
    enter_frame
    ln s_ip, (-1 * NATIVE)(s_ip)
    addi s_ip, s_ip, o_payload
    go
endfunc _code_rundef

func _code_runindirect
    addi s_ip, s_ip, NATIVE
    enter_frame
    ln s_ip, (-1 * NATIVE)(s_ip)
    ln s_ip, o_payload(s_ip)
    go
endfunc _code_runindirect

    .section .data

    .macro _newword label, name, code, link=1001b
        .set .Llink_\@, \link
        .pushsection .rodata.str1.1, "aMS", @progbits, 1
1010:
        .string "\name"
1011:
        .popsection

        .p2align LGNATIVE
        .type \label, @object
1001:
\label:
        nbyte \code
        nbyte .Llink_\@
        nbyte 1010b
        nbyte 1011b - 1010b - 1
    .endm

    .macro codeword label, name, link=1001b
        _newword \label, "\name", _code_\label, \link
        .pushsection .text
func _code_\label
    .endm

    .macro endcode label
endfunc _code_\label
        .popsection
        .size \label, . - \label
    .endm

    .macro defword label, name
        _newword \label, "\name", _code_rundef
    .endm

    .macro enddef label
        .size \label, . - \label
    .endm

    .macro constword label, name, value
        _newword \label, "\name", _code_runconst
        nbyte \value
        .size \label, . - \label
    .endm

    .macro varword label, name, var_label
        constword \label, "\name", \var_label
        .pushsection .sbss, "aw", @nobits
        .p2align LGNATIVE
        .type \var_label, @object
\var_label:
        .zero NATIVE
        .size \var_label, . - \var_label
        .popsection
    .endm

    .macro str string
        nbyte _f_litstr, 1022f - 1021f
1021:
        .ascii "\string"
1022:
        .p2align LGNATIVE
    .endm

    .macro list label
        nbyte _f_litlist, \label - 1021f
1021:
    .endm

    // First word in the linked list requires link = -1
codeword _f_bkpt, "bkpt", -1
    ebreak
    next
endcode _f_bkpt

codeword _f_return, "return"
    addi s_rsp, s_rfp, -2 * NATIVE
    ln s_rfp, (0 * NATIVE)(s_rsp)
    ln s_ip, (1 * NATIVE)(s_rsp)
    go
endcode _f_return

codeword _f_lit, "_lit"
    ln a0, (1 * NATIVE)(s_ip)
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    addi s_ip, s_ip, 2 * NATIVE
    go
endcode _f_lit

codeword _f_litstr, "_litstr"
    ln a1, (1 * NATIVE)(s_ip)
    addi a0, s_ip, 2 * NATIVE
    sn a0, (0 * NATIVE)(s_dsp)
    sn a1, (1 * NATIVE)(s_dsp)
    addi s_dsp, s_dsp, 2 * NATIVE
    add s_ip, a0, a1
    addi s_ip, s_ip, NATIVE - 1
    andi s_ip, s_ip, ~ (NATIVE - 1)
    go
endcode _f_litstr

codeword _f_litlist, "_litlist"
    ln a1, (1 * NATIVE)(s_ip)
    addi a0, s_ip, 2 * NATIVE
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, 1 * NATIVE
    add s_ip, s_ip, a1
    addi s_ip, s_ip, 2 * NATIVE
    go
endcode _f_litlist

codeword _f_run, "run"
    addi s_ip, s_ip, NATIVE
    enter_frame
    addi s_dsp, s_dsp, - NATIVE
    ln s_ip, (s_dsp)
    go
endcode _f_run

    // Stack frame primitives

codeword _f_lcomma, "l,"
    addi s_dsp, s_dsp, -1 * NATIVE
    ln a0, (s_dsp)
    sn a0, (s_rsp)
    addi s_rsp, s_rsp, NATIVE
    next
endcode _f_lcomma

codeword _f_lload, "l@"
    ln a0, (-1 * NATIVE)(s_dsp)
    slli a0, a0, LGNATIVE
    add a0, s_rfp, a0
    ln a0, (a0)
    sn a0, (-1 * NATIVE)(s_dsp)
    next
endcode _f_lload

codeword _f_lstore, "l!"
    addi s_dsp, s_dsp, -2 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    slli a1, a1, LGNATIVE
    add a1, s_rfp, a1
    sn a0, (a1)
    next
endcode _f_lstore

codeword _f_lhere, "lhere"
    sn s_rsp, (s_dsp)
    addi s_dsp, s_dsp, 1 * NATIVE
    next
endcode _f_lhere

codeword _f_lallot, "lallot"
    addi s_dsp, s_dsp, -1 * NATIVE
    ln a0, (s_dsp)
    add s_rsp, s_rsp, a0
    next
endcode _f_lallot

codeword _f_lalign, "lalign"
    addi s_rsp, s_rsp, NATIVE - 1
    andi s_rsp, s_rsp, ~ (NATIVE - 1)
    next
endcode _f_lalign

    // Control flow primitives

codeword _f_jump, "_jump"
    ln s_ip, (1 * NATIVE)(s_ip)
    go
endcode _f_jump

codeword _f_jif, "_jif"
    addi s_dsp, s_dsp, -1 * NATIVE
    ln a0, (s_dsp)
    ln a1, (1 * NATIVE)(s_ip)
    addi s_ip, s_ip, 2 * NATIVE
    beqz a0, 1f
    mv s_ip, a1
1:
    go
endcode _f_jif

    .macro load_like label, name, insn
    codeword \label, "\name"
        ln a0, (-1 * NATIVE)(s_dsp)
        \insn a0, (a0)
        sn a0, (-1 * NATIVE)(s_dsp)
        next
    endcode \label
    .endm

    load_like _f_load, "@", ln
    load_like _f_b_load, "b@", lb
    load_like _f_b_load_u, "b@u", lbu
    load_like _f_h_load, "h@", lh
    load_like _f_h_load_u, "h@u", lhu
    load_like _f_w_load, "w@", lw

#if __riscv_xlen == 32
    load_like _f_w_load_u, "w@u", lw
#else
    load_like _f_w_load_u, "w@u", lwu
#endif

    .macro store_like label, name, insn
    codeword \label, "\name"
        addi s_dsp, s_dsp, -2 * NATIVE
        ln a0, (0 * NATIVE)(s_dsp)
        ln a1, (1 * NATIVE)(s_dsp)
        \insn a0, (a1)
        next
    endcode \label
    .endm

    store_like _f_store, "!", sn
    store_like _f_b_store, "b!", sb
    store_like _f_h_store, "h!", sh
    store_like _f_w_store, "w!", sw

    .macro alu2word label, name, insn
codeword \label, "\name"
        addi s_dsp, s_dsp, -1 * NATIVE
        ln a0, (-1 * NATIVE)(s_dsp)
        ln a1, (0 * NATIVE)(s_dsp)
        \insn a0, a0, a1
        sn a0, (-1 * NATIVE)(s_dsp)
        next
endcode \label
    .endm

    alu2word _f_add, "+", add
    alu2word _f_sub, "-", sub
    // alu2word _f_mul, "*", mul
    // alu2word _f_div, "/", div
    alu2word _f_shl, "<<", sll
    alu2word _f_shr, ">>", sra
    alu2word _f_and, "&", and
    alu2word _f_or, "|", or
    alu2word _f_xor, "^", xor
    alu2word _f_lt, "<", slt

    .macro alu1word label, name, insn
codeword \label, "\name"
        ln a0, (-1 * NATIVE)(s_dsp)
        \insn a0, a0
        sn a0, (-1 * NATIVE)(s_dsp)
        next
endcode \label
    .endm

    alu1word _f_neg, "neg", neg
    alu1word _f_not, "not", not
    alu1word _f_eqz, "=0", seqz
    alu1word _f_ltz, "<0", sltz

    // Utilities

codeword _f_mul_10, "*10"
    ln a0, (-1 * NATIVE)(s_dsp)
    slli a0, a0, 1 // a0 = n * 2
    slli a1, a0, 2 // a1 = (n * 2) * 4 = n * 8
    add a0, a0, a1 // a0 = n * 2 + n * 8 = n * 10
    sn a0, (-1 * NATIVE)(s_dsp)
    next
endcode _f_mul_10

codeword _f_memcpy, "memcpy"
    addi s_dsp, s_dsp, -3 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    ln a2, (2 * NATIVE)(s_dsp)
    call memcpy
    next
endcode _f_memcpy

codeword _f_memcmp, "memcmp"
    addi s_dsp, s_dsp, -2 * NATIVE
    ln a0, (-1 * NATIVE)(s_dsp)
    ln a1, (0 * NATIVE)(s_dsp)
    ln a2, (1 * NATIVE)(s_dsp)
    call memcmp
    sn a0, (-1 * NATIVE)(s_dsp)
    next
endcode _f_memcmp

codeword _f_sys_exit, "sys_exit"
    li a0, 0
    call exit
    unimp
endcode _f_sys_exit

codeword _f_sys_putchar, "sys_putchar"
    addi s_dsp, s_dsp, -1 * NATIVE
    lbu a0, (s_dsp)
    call putchar
    next
endcode _f_sys_putchar

codeword _f_sys_getchar, "sys_getchar"
    call getchar
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, 1 * NATIVE
    next
endcode _f_sys_getchar

codeword _f_dump, "_dump"
    la a0, data_stack
    sub a1, s_dsp, a0
    srli a1, a1, LGNATIVE
    call _dump_array
    next
endcode _f_dump

codeword _f_dump_array, "_dump_array"
    addi s_dsp, s_dsp, -2 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    call _dump_array
    next
endcode _f_dump_array

constword _f_native, "native", NATIVE
constword _f_lgnative, "lgnative", LGNATIVE

constword _f_of_rundef, "=_rundef", _code_rundef
constword _f_of_runindirect, "=_runindirect", _code_runindirect
constword _f_of_runconst, "=_runconst", _code_runconst

constword _f_of_bootstrap_script, "=bootstrap_script", bootstrap_script
constword _f_of_bootstrap_script_end, "=bootstrap_script_end", bootstrap_script_end

varword _f_of_here, "=here", here_pointer
varword _f_of_last, "=last", last_word

defword _f_dup, "dup"
    // ( a -- a a )
    nbyte _f_lcomma
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_return
enddef _f_dup

defword _f_nip, "nip"
    // ( a b -- b )
    nbyte _f_lcomma
    nbyte _f_drop
    nbyte _f_lit, 0, _f_lload
    nbyte _f_return
enddef _f_nip

defword _f_swap, "swap"
    // ( a b -- b a )
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_return
enddef _f_swap

defword _f_rot, "rot"
    // ( a b c -- b c a )
    nbyte _f_lcomma, _f_lcomma, _f_lcomma
    nbyte _f_lit, 1, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 2, _f_lload
    nbyte _f_return
enddef _f_rot

defword _f_nrot, "nrot"
    // ( a b c -- c a b )
    nbyte _f_rot, _f_rot
    nbyte _f_return
enddef _f_nrot

defword _f_drop, "drop"
    // ( a -- )
    nbyte _f_lcomma
    nbyte _f_return
enddef _f_drop

defword _f_over, "over"
    // ( a b -- a b a )
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 1, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_return
enddef _f_over

defword _f_tuck, "tuck"
    // ( a b -- b a b )
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_return
enddef _f_tuck

defword _f_pdup, "pdup"
    // ( a b -- a b a b )
    nbyte _f_over, _f_over
    nbyte _f_return
enddef _f_pdup

defword _f_pdrop, "pdrop"
    // ( a b -- )
    nbyte _f_drop, _f_drop
    nbyte _f_return
enddef _f_pdrop

defword _f_prot, "prot"
    // ( a b c d e f -- c d e f a b )
    //   5 4 3 2 1 0    3 2 1 0 5 4
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 3, _f_lload
    nbyte _f_lit, 2, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 5, _f_lload
    nbyte _f_lit, 4, _f_lload
    nbyte _f_return
enddef _f_prot

defword _f_pnrot, "pnrot"
    // ( a b c d e f -- e f a b c d )
    nbyte _f_prot, _f_prot
    nbyte _f_return
enddef _f_pnrot

defword _f_pswap, "pswap"
    // ( a b c d -- c d a b )
    nbyte _f_rot, _f_lcomma
    nbyte _f_rot, _f_lit, 0, _f_lload
    nbyte _f_return
enddef _f_pswap

defword _f_add_store, "+!"
    nbyte _f_dup, _f_load
    nbyte _f_rot
    nbyte _f_add, _f_swap, _f_store
    nbyte _f_return
enddef _f_add_store

defword _f_add_n, "+n"
    // ( a b -- { a + b * NATIVE } )
    nbyte _f_lgnative, _f_shl, _f_add
    nbyte _f_return
enddef _f_add_n

defword _f_gez, ">=0"
    nbyte _f_ltz, _f_eqz
    nbyte _f_return
enddef _f_gez

defword _f_gtz, ">0"
    nbyte _f_neg, _f_ltz
    nbyte _f_return
enddef _f_gtz

defword _f_lez, "<=0"
    nbyte _f_gtz, _f_eqz
    nbyte _f_return
enddef _f_lez

defword _f_eq, "="
    nbyte _f_sub, _f_eqz
    nbyte _f_return
enddef _f_eq

defword _f_ge, ">="
    nbyte _f_lt, _f_eqz
    nbyte _f_return
enddef _f_ge

defword _f_gt, ">"
    nbyte _f_swap, _f_lt
    nbyte _f_return
enddef _f_gt

defword _f_le, "<="
    nbyte _f_gt, _f_eqz
    nbyte _f_return
enddef _f_le

defword _f_between, "between"
    // ( a low up -- t ) low <= a && a <= up
    nbyte _f_rot, _f_dup, _f_nrot
    // ( low a up a )
    nbyte _f_ge, _f_nrot, _f_le, _f_and
    nbyte _f_return
enddef _f_between

defword _f_aligned, "aligned"
    // ( p -- p )
    nbyte _f_native, _f_add, _f_lit, 1, _f_sub
    nbyte _f_native, _f_neg, _f_and
    nbyte _f_return
enddef _f_aligned

defword _f_align, "align"
    nbyte _f_of_here, _f_load
    nbyte _f_aligned
    nbyte _f_of_here, _f_store
    nbyte _f_return
enddef _f_align

defword _f_ifelse, "ifelse"
    // ( t l l -- )
    nbyte _f_rot
    nbyte _f_jif, 1f
    // else
    nbyte _f_nip
    nbyte _f_jump, 2f
1:
    // then
    nbyte _f_drop
2:
    nbyte _f_run
    nbyte _f_return
enddef _f_ifelse

defword _f_if, "if"
    // ( t l -- )
    nbyte _f_swap, _f_eqz, _f_jif, 1f
    nbyte _f_run
    nbyte _f_jump, 2f
1:
    nbyte _f_drop
2:
    nbyte _f_return
enddef _f_if

defword _f_repeat, "repeat"
    // ( l:( -- t ) -- )
    // Repeat if returns true, stop otherwise
    nbyte _f_lcomma
1:
    nbyte _f_lit, 0, _f_lload
    nbyte _f_run
    nbyte _f_jif, 1b

    nbyte _f_return
enddef _f_repeat

defword _f_count, "count"
    // ( n l:( n -- ) -- )
    // Loops from 0 (inclusive) to n (exclusive)
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 0, _f_lcomma
1:
    nbyte _f_lit, 2, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_eq, _f_jif, 2f
    nbyte _f_lit, 2, _f_lload
    nbyte _f_lit, 0, _f_lload, _f_run
    nbyte _f_lit, 2, _f_lload
    nbyte _f_lit, 1, _f_add
    nbyte _f_lit, 2, _f_lstore
    nbyte _f_jump, 1b
2:
    nbyte _f_return
enddef _f_count

defword _f_begin_case, "begin_case"
    // ( -- 0 )
    nbyte _f_lit, 0
    nbyte _f_return
enddef _f_begin_case

defword _f_case, "case"
    // ( ..a 0 l:( ..a -- t:cond ) l:( ..a -- ..s ) -- ..a 0 ) if t:cond == 0
    // ( ..a 0 l:( ..a -- t:cond ) l:( ..a -- ..s ) -- ..s 1 ) if t:cond != 0
    // ( ..a 1 l:( ..a -- t:cond ) l:( ..a -- ..s ) -- ..a 1 )

    nbyte _f_rot
    list 1f
        nbyte _f_pdrop
        nbyte _f_lit, 1
        nbyte _f_return
    1:
    list 1f
        // ( l:( -- t:cond) l:( -- ..s ) )
        nbyte _f_lcomma
        // ( l:( -- t:cond) )
        nbyte _f_run
        // ( t:cond )
        nbyte _f_lit, 0, _f_lload
        nbyte _f_swap
        // ( l:( -- ..s ) t:cond )
        list 2f
            nbyte _f_run
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        list 2f
            nbyte _f_drop
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_ifelse
        nbyte _f_return
    1:
    nbyte _f_ifelse
    nbyte _f_return
enddef _f_case

defword _f_end_case, "end_case"
    // ( t -- )
    nbyte _f_drop
    nbyte _f_return
enddef _f_end_case

defword _f_s_dot, "s."
    list 1f
        nbyte _f_drop
        nbyte _f_dup, _f_b_load_u, _f_sys_putchar
        nbyte _f_lit, 1, _f_add
        nbyte _f_return
    1:
    nbyte _f_count
    nbyte _f_drop
    nbyte _f_return
enddef _f_s_dot

defword _f_name_of_def, "name_of_def"
    // ( p:def -- p:name n:name )
    nbyte _f_dup
    nbyte _f_lit, 2, _f_add_n, _f_load, _f_swap
    nbyte _f_lit, 3, _f_add_n, _f_load
    nbyte _f_return
enddef _f_name_of_def

defword _f_find_word, "find_word"
    // ( p:word n:word -- p:def )
    // -1 if not found

    nbyte _f_of_last, _f_load

    list 1f
        // ( p:word n:word p:list )
        nbyte _f_begin_case
        list 2f
            nbyte _f_dup, _f_lit, -1, _f_eq
            nbyte _f_return
        2:
        list 2f
            // Not found
            nbyte _f_drop, _f_pdrop
            nbyte _f_lit, -1
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_case

        list 2f
            nbyte _f_lcomma
            nbyte _f_pdup, _f_lit, 0, _f_lload, _f_name_of_def
            nbyte _f_s_eq
            nbyte _f_lit, 0, _f_lload, _f_swap
            nbyte _f_return
        2:
        list 2f
            // Found
            nbyte _f_nrot, _f_pdrop
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_case

        list 2f
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        list 2f
            // Next
            nbyte _f_lit, 1, _f_add_n, _f_load
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        nbyte _f_case

        nbyte _f_end_case
        nbyte _f_return
    1:
    nbyte _f_repeat
    nbyte _f_return

enddef _f_find_word

defword _f_parse_decimal, "parse_decimal"
    // ( p:word n:word -- number t:success )
    nbyte _f_lit, 0, _f_lit, 1, _f_pswap
    // ( number t:success p:word n:word )
    // Check non-zero length
    nbyte _f_rot, _f_over, _f_eqz, _f_eqz, _f_and, _f_nrot
    list 1f
        nbyte _f_drop
        // ( number t:success p:word )
        nbyte _f_dup, _f_b_load_u
        nbyte _f_lit, '0', _f_lit, '9', _f_between
        // ( number t:success p:word t:char_okay )
        nbyte _f_rot, _f_and, _f_swap
        // ( number t:success p:word )
        nbyte _f_rot, _f_over
        // ( t:success p:word number p:word )
        nbyte _f_b_load_u, _f_lit, '0', _f_sub
        nbyte _f_swap, _f_mul_10, _f_add, _f_nrot
        nbyte _f_lit, 1, _f_add
        nbyte _f_return
    1:
    nbyte _f_count
    nbyte _f_drop
    nbyte _f_return
enddef _f_parse_decimal

defword _f_is_whitespace, "?whitespace"
    // ( byte -- t )
    nbyte _f_lit, 0
    nbyte _f_over, _f_lit, ' ', _f_eq, _f_or
    nbyte _f_over, _f_lit, '\t', _f_eq, _f_or
    nbyte _f_over, _f_lit, '\r', _f_eq, _f_or
    nbyte _f_over, _f_lit, '\n', _f_eq, _f_or
    nbyte _f_nip
    nbyte _f_return
enddef _f_is_whitespace

defword _f_s_eq, "s="
    // String equal
    // ( p:a n:a p:b n:b -- t )
    nbyte _f_rot, _f_tuck, _f_eq // ( p:a p:b n:a t:equal )
    list 1f
        nbyte _f_memcmp, _f_eqz
        nbyte _f_return
    1:
    list 1f
        nbyte _f_drop, _f_pdrop
        nbyte _f_lit, 0
        nbyte _f_return
    1:
    nbyte _f_ifelse
    nbyte _f_return
enddef _f_s_eq

defword _f_first_word_start, "_first_word_start"
    // ( p:end p:input -- n:word )
    nbyte _f_lit, 0, _f_nrot // ( n p:end p:input )
    list 1f
        nbyte _f_begin_case
            list 2f
                // End of input
                nbyte _f_pdup, _f_eq
                nbyte _f_return
            2:
            list 2f
                nbyte _f_pdrop, _f_lit, 0
                nbyte _f_return
            2:
            nbyte _f_case

            list 2f
                // Found whitespace
                nbyte _f_dup, _f_b_load_u, _f_is_whitespace
                nbyte _f_return
            2:
            list 2f
                nbyte _f_pdrop, _f_lit, 0
                nbyte _f_return
            2:
            nbyte _f_case

            list 2f
                // Otherwise, check next byte
                nbyte _f_lit, 1
                nbyte _f_return
            2:
            list 2f
                nbyte _f_lit, 1, _f_add
                nbyte _f_rot, _f_lit, 1, _f_add, _f_nrot
                nbyte _f_lit, 1
                nbyte _f_return
            2:
            nbyte _f_case
        nbyte _f_end_case

        nbyte _f_return
    1:
    nbyte _f_repeat
    nbyte _f_return
enddef _f_first_word_start

defword _f_first_word_string, "_first_word_string"
    // ( p:end p:input -- n:word )
    nbyte _f_lit, 1, _f_add
    nbyte _f_lit, 1, _f_nrot
    list 1f
        // ( n:word p:end p:input )
        nbyte _f_begin_case
        list 2f
            nbyte _f_pdup, _f_eq
            nbyte _f_return
        2:
        list 2f
            nbyte _f_pdrop
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_case

        list 2f
            nbyte _f_dup, _f_b_load_u, _f_lit, '"', _f_eq
            nbyte _f_return
        2:
        list 2f
            nbyte _f_pdrop
            nbyte _f_lit, 1, _f_add
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_case

        list 2f
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        list 2f
            nbyte _f_lit, 1, _f_add
            nbyte _f_rot, _f_lit, 1, _f_add, _f_nrot
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        nbyte _f_case

        nbyte _f_end_case
        nbyte _f_return
    1:
    nbyte _f_repeat
    nbyte _f_return
enddef _f_first_word_string

defword _f_first_word, "_first_word"
    // ( p:end p:input -- p:word n:word )
    // End of input and length 0 if no word found

    list 1f
        nbyte _f_begin_case
            list 2f
                // End of input
                nbyte _f_pdup, _f_eq
                nbyte _f_return
            2:
            list 2f
                nbyte _f_nip, _f_lit, 0 // ( p:input 0 )
                nbyte _f_lit, 0
                nbyte _f_return
            2:
            nbyte _f_case

            list 2f
                nbyte _f_dup, _f_b_load_u, _f_lit, ';', _f_eq
                nbyte _f_return
            2:
            list 2f
                nbyte _f_tuck, _f_sub
                nbyte _f_lit, 0
                nbyte _f_return
            2:
            nbyte _f_case

            list 2f
                nbyte _f_dup, _f_b_load_u, _f_lit, '"', _f_eq
                nbyte _f_return
            2:
            list 2f
                nbyte _f_dup, _f_nrot
                nbyte _f_first_word_string
                nbyte _f_lit, 0
                nbyte _f_return
            2:
            nbyte _f_case

            list 2f
                nbyte _f_dup, _f_b_load_u, _f_is_whitespace
                nbyte _f_return
            2:
            list 2f
                nbyte _f_lit, 1, _f_add
                nbyte _f_lit, 1
                nbyte _f_return
            2:
            nbyte _f_case

            list 2f
                nbyte _f_lit, 1
                nbyte _f_return
            2:
            list 2f
                nbyte _f_dup, _f_nrot // ( p:word p:end p:word )
                nbyte _f_first_word_start // ( p:word n:word )
                nbyte _f_lit, 0
                nbyte _f_return
            2:
            nbyte _f_case
        nbyte _f_end_case
        nbyte _f_return
    1:
    nbyte _f_repeat
    nbyte _f_return
enddef _f_first_word

defword _f_append_token, "_append_token"
    // ( p:tokens n -- p:tokens )
    nbyte _f_over, _f_store
    nbyte _f_native, _f_add
    nbyte _f_return
enddef _f_append_token

defword _f_do_list_start, "_do_list_start"
    // ( p:fill p:tokens -- p:tokens p:tokens )
    nbyte _f_over, _f_append_token
    nbyte _f_nip, _f_dup
    nbyte _f_return
enddef _f_do_list_start

defword _f_do_list_end, "_do_list_end"
    // ( p:fill p:tokens -- p:oldfill p:tokens )
    nbyte _f_swap, _f_native, _f_sub, _f_dup
    // ( p:tokens p:fill p:fill )
    nbyte _f_load, _f_nrot
    // ( p:oldfill p:tokens p:fill )
    nbyte _f_pdup, _f_sub, _f_native, _f_sub, _f_swap, _f_store
    nbyte _f_return
enddef _f_do_list_end

defword _f_process_word, "_process_word"
    // ( p:fill p:tokens p:word n:word -- p:fill p:tokens 1 ) if success
    // ( ... -- p:msg n:msg 0 ) if failure

    nbyte _f_begin_case
    list 1f
        // Empty word
        nbyte _f_dup, _f_eqz
        nbyte _f_return
    1:
    list 1f
        nbyte _f_pdrop
        str "Empty word"
        nbyte _f_lit, 0
        nbyte _f_return
    1:
    nbyte _f_case

    list 1f
        // Comment
        nbyte _f_over, _f_b_load_u, _f_lit, ';', _f_eq
        nbyte _f_return
    1:
    list 1f
        nbyte _f_pdrop
        nbyte _f_lit, 1
        nbyte _f_return
    1:
    nbyte _f_case

    list 1f
        // Literal string
        nbyte _f_over, _f_b_load_u, _f_lit, '"', _f_eq
        nbyte _f_return
    1:
    list 1f
        nbyte _f_pdup, _f_add, _f_lit, 1, _f_sub
        nbyte _f_b_load_u, _f_lit, '"', _f_eq
        list 2f
            nbyte _f_lit, 2, _f_sub, _f_lcomma
            nbyte _f_lit, 1, _f_add, _f_lcomma
            nbyte _f_lit, _f_litstr, _f_append_token
            nbyte _f_lit, 0, _f_lload, _f_append_token
            nbyte _f_dup, _f_lit, 1, _f_lload, _f_lit, 0, _f_lload, _f_memcpy
            nbyte _f_lit, 0, _f_lload, _f_add
            nbyte _f_aligned
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        list 2f
            nbyte _f_pdrop, _f_pdrop
            str "Unterminated string"
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_ifelse
        nbyte _f_return
    1:
    nbyte _f_case

    list 1f
        // Start of list
        nbyte _f_pdup
        str "["
        nbyte _f_s_eq
        nbyte _f_return
    1:
    list 1f
        nbyte _f_pdrop
        nbyte _f_lit, _f_litlist, _f_append_token
        nbyte _f_do_list_start
        nbyte _f_lit, 1
        nbyte _f_return
    1:
    nbyte _f_case

    list 1f
        // End of list
        nbyte _f_pdup
        str "]"
        nbyte _f_s_eq
        nbyte _f_return
    1:
    list 1f
        nbyte _f_pdrop
        nbyte _f_over, _f_lit, -1, _f_eq
        list 2f
            nbyte _f_pdrop
            str "Unmatched closing bracket"
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        list 2f
            nbyte _f_lit, _f_return, _f_append_token
            nbyte _f_do_list_end
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        nbyte _f_ifelse
        nbyte _f_return
    1:
    nbyte _f_case

    list 1f
        // Number literal
        nbyte _f_over, _f_b_load_u
        nbyte _f_lit, '0', _f_lit, '9', _f_between
        nbyte _f_return
    1:
    list 1f
        nbyte _f_parse_decimal
        list 2f
            // ( p:fill p:tokens num )
            nbyte _f_swap, _f_lit, _f_lit, _f_append_token, _f_swap
            nbyte _f_append_token
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        list 2f
            nbyte _f_drop, _f_pdrop
            str "Invalid number"
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_ifelse
        nbyte _f_return
    1:
    nbyte _f_case

    list 1f
        // Otherwise, find word in dictionary
        nbyte _f_lit, 1
        nbyte _f_return
    1:
    list 1f
        nbyte _f_pdup, _f_find_word
        // ( p:fill p:tokens p:word n:word p:def )
        nbyte _f_dup, _f_lit, -1, _f_eq
        list 2f
            nbyte _f_drop, _f_pdrop, _f_pdrop
            str "Undefined word"
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        list 2f
            nbyte _f_nrot, _f_pdrop, _f_append_token
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        nbyte _f_ifelse
        nbyte _f_return
    1:
    nbyte _f_case

    nbyte _f_end_case
    nbyte _f_return
enddef _f_process_word

defword _f_process_line, "process_line"
    // ( p:fill p:tokens p:line n:line -- p:fill p:tokens 1 ) if success
    // ( ... -- p:word n:word p:msg n:msg 0 ) if failure

    nbyte _f_over, _f_add, _f_swap
    // ( p:fill p:tokens p:end p:line )

    list 1f
        nbyte _f_pdup, _f_pnrot
        // ( p:end p:line p:fill p:tokens p:end p:line )
        nbyte _f_first_word
        // ( p:end p:line p:fill p:tokens p:word n:word )
        nbyte _f_dup, _f_eqz
        list 2f
            // End of line
            nbyte _f_pdrop, _f_pswap, _f_pdrop
            // ( p:fill p:tokens )
            nbyte _f_lit, 1 // Success
            nbyte _f_lit, 0 // Don't continue
            nbyte _f_return
        2:
        list 2f
            nbyte _f_pdup, _f_pnrot
            // ( p:end p:line p:word n:word p:fill p:tokens p:word n:word )
            nbyte _f_process_word

            list 3f
                // Success
                // ( p:end p:line p:word n:word p:fill p:tokens )
                nbyte _f_pnrot, _f_add, _f_nip
                // ( p:fill p:tokens p:end p:line )
                nbyte _f_lit, 1 // Do continue
                nbyte _f_return
            3:
            list 3f
                // Failure
                // ( p:end p:line p:word n:word p:msg n:msg )
                nbyte _f_prot, _f_pdrop
                // ( p:word n:word p:msg n:msg )
                nbyte _f_lit, 0 // Failure
                nbyte _f_lit, 0 // Don't continue
                nbyte _f_return
            3:
            nbyte _f_ifelse
            nbyte _f_return
        2:
        nbyte _f_ifelse
        nbyte _f_return
    1:
    nbyte _f_repeat
    nbyte _f_return
enddef _f_process_line

defword _f_print_error_line, "print_error_line"
    // ( p:line n:line p:word n:word -- )
    nbyte _f_lcomma, _f_lcomma
    // ( p:line n:line )
    nbyte _f_over, _f_add, _f_swap
    // ( p:lineend p:line )
    nbyte _f_dup, _f_lit, 1, _f_lload, _f_swap, _f_sub, _f_s_dot
    str ">>>"
    nbyte _f_s_dot
    nbyte _f_lit, 1, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_pdup, _f_s_dot
    str "<<<"
    nbyte _f_s_dot
    nbyte _f_add
    // ( p:lineend p:afterword )
    nbyte _f_dup, _f_nrot, _f_sub, _f_s_dot
    nbyte _f_return
enddef _f_print_error_line

defword _f_buf_get_line, "buf_get_line"
    // ( p:buf n:buf -- n:line )
    nbyte _f_over, _f_add, _f_over
    list 1f
        // ( p:buf p:end p:line-end )
        nbyte _f_begin_case
        list 2f
            // Got EOF
            nbyte _f_pdup, _f_eq
            nbyte _f_return
        2:
        list 2f
            nbyte _f_nip, _f_swap, _f_sub
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_case

        list 2f
            // Got newline
            nbyte _f_dup, _f_b_load_u
            nbyte _f_lit, '\n', _f_eq
            nbyte _f_return
        2:
        list 2f
            nbyte _f_nip, _f_swap, _f_sub
            nbyte _f_lit, 1, _f_add
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        nbyte _f_case

        list 2f
            // Other char, keep going
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        list 2f
            nbyte _f_lit, 1, _f_add
            nbyte _f_lit, 1
            nbyte _f_return
        2:
        nbyte _f_case

        nbyte _f_end_case
        nbyte _f_return
    1:
    nbyte _f_repeat
    nbyte _f_return
enddef _f_buf_get_line

defword _f_evaluate, "evaluate"
    // ( p:buf n:buf -- ??? )
    nbyte _f_lit, -1
    nbyte _f_align, _f_of_here, _f_load
    nbyte _f_pswap
    // ( p:fill p:token p:buf n:buf )
    list 1f
        nbyte _f_dup, _f_eqz
        list 2f
            nbyte _f_pdrop, _f_pdrop
            nbyte _f_lit, 0
            nbyte _f_return
        2:
        list 2f
            nbyte _f_pdup, _f_buf_get_line
            // ( p:fill p:token p:buf n:buf n:line )
            nbyte _f_lcomma
            nbyte _f_over, _f_lit, 0, _f_lload
            // ( p:fill p:token p:buf n:buf p:line n:line )
            nbyte _f_prot, _f_pswap
            // ( p:buf n:buf p:fill p:token p:line n:line )
            nbyte _f_pdup, _f_pnrot
            // ( p:buf n:buf p:line n:line p:fill p:token p:line n:line )
            nbyte _f_process_line
            list 3f
                // ( p:buf n:buf p:line n:line p:fill p:token )
                nbyte _f_pnrot, _f_nip
                // ( p:fill p:token p:buf n:buf n:line )
                nbyte _f_tuck, _f_sub
                // ( p:fill p:token p:buf n:line n:newbuf )
                nbyte _f_nrot, _f_add, _f_swap
                // ( p:fill p:token p:newbuf n:newbuf )
                nbyte _f_pswap
                // ( p:newbuf n:newbuf p:fill p:token )
                nbyte _f_over, _f_lit, -1, _f_eq
                nbyte _f_over, _f_of_here, _f_load, _f_eq, _f_eqz, _f_and
                list 4f
                    nbyte _f_lit, _f_return, _f_append_token
                    nbyte _f_nip
                    // ( p:newbuf n:newbuf p:token )
                    nbyte _f_of_here, _f_load, _f_swap
                    // ( p:newbuf n:newbuf p:start_tokens p:token )
                    nbyte _f_of_here, _f_store
                    // ( p:newbuf n:newbuf p:start_tokens )
                    nbyte _f_nrot, _f_lcomma, _f_lcomma
                    nbyte _f_run // Run with clean stack
                    nbyte _f_lit, 1, _f_lload
                    nbyte _f_lit, 0, _f_lload
                    nbyte _f_lit, -1
                    nbyte _f_align, _f_of_here, _f_load
                    // ( p:newbuf n:newbuf p:fill p:token )
                    nbyte _f_return
                4:
                nbyte _f_if
                nbyte _f_pswap
                // ( p:fill p:token p:newbuf n:newbuf )
                nbyte _f_lit, 1
                nbyte _f_return
            3:
            list 3f
                // ( p:buf n:buf p:line n:line p:word n:word p:msg n:msg )
                // Print error and quit evaluating
                nbyte _f_s_dot
                nbyte _f_lit, '\n', _f_sys_putchar
                nbyte _f_print_error_line
                nbyte _f_lit, 0
                nbyte _f_return
            3:
            nbyte _f_ifelse
            nbyte _f_return
        2:
        nbyte _f_ifelse
        nbyte _f_return
    1:
    nbyte _f_repeat
    nbyte _f_return
enddef _f_evaluate

defword _f_init, "_init"
    nbyte _f_of_bootstrap_script, _f_of_bootstrap_script_end
    nbyte _f_over, _f_sub
    nbyte _f_evaluate
    nbyte _f_sys_exit
enddef _f_init

    .set _last_word, 1001b

    .section .rodata
    .type bootstrap_script, @object
bootstrap_script:
    .incbin "bootstrap.five"
    .size bootstrap_script, . - bootstrap_script
bootstrap_script_end:

    .section .text

    .global main
func main
    la a0, _last_word
    sn a0, last_word, a1
    la a0, allot_space
    sn a0, here_pointer, a1

    la s_dsp, data_stack
    la s_rsp, return_stack
    mv s_rfp, s_rsp
    la s_ip, _f_init
    addi s_ip, s_ip, o_payload
    go
endfunc main

    .section .bss
    .p2align LGNATIVE
data_stack:
    .zero 4096
return_stack:
    .zero 4096
allot_space:
    .zero 4096 * 4

    .section .note.GNU-stack, "", @progbits
