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
    addi a0, s_ip, 1 * NATIVE
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, 1 * NATIVE
    add s_ip, s_ip, a1
    addi s_ip, s_ip, 2 * NATIVE
    go
endcode _f_litlist

codeword _f_runraw, "runraw"
    addi s_ip, s_ip, NATIVE
    enter_frame
    addi s_dsp, s_dsp, - NATIVE
    ln s_ip, (s_dsp)
    go
endcode _f_runraw

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
    alu2word _f_mul, "*", mul
    alu2word _f_div, "/", div
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

codeword _f_memcpy, "memcpy"
    addi sp, sp, -3 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    ln a2, (2 * NATIVE)(s_dsp)
    call memcpy
    next
endcode _f_memcpy

codeword _f_memcmp, "memcmp"
    addi sp, sp, -3 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    ln a2, (2 * NATIVE)(s_dsp)
    call memcmp
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

constword _f_native, "native", NATIVE
constword _f_lgnative, "lgnative", LGNATIVE

varword _f_of_here, "=here", here_pointer
varword _f_of_last, "=last", last_word

defword _f_dup, "dup"
    nbyte _f_lcomma
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_return
enddef _f_dup

defword _f_nip, "nip"
    nbyte _f_lcomma
    nbyte _f_drop
    nbyte _f_lit, 0, _f_lload
    nbyte _f_return
enddef _f_nip

defword _f_swap, "swap"
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_return
enddef _f_swap

defword _f_rot, "rot"
    nbyte _f_lcomma, _f_lcomma, _f_lcomma
    nbyte _f_lit, 1, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 2, _f_lload
    nbyte _f_return
enddef _f_rot

defword _f_nrot, "nrot"
    nbyte _f_rot, _f_rot
    nbyte _f_return
enddef _f_nrot

defword _f_drop, "drop"
    nbyte _f_lcomma
    nbyte _f_return
enddef _f_drop

defword _f_over, "over"
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 1, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_return
enddef _f_over

defword _f_add_store, "+!"
    nbyte _f_dup, _f_load
    nbyte _f_rot
    nbyte _f_add, _f_swap, _f_store
    nbyte _f_return
enddef _f_add_store

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

defword _f_run, "run"
    nbyte _f_native, _f_add
    nbyte _f_runraw
    nbyte _f_return
enddef _f_run

defword _f_ifelse, "ifelse"
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
    nbyte _f_swap, _f_jif, 1f
    nbyte _f_run
    nbyte _f_jump, 2f
1:
    nbyte _f_drop
2:
    nbyte _f_return
enddef _f_if

defword _f_repeat, "repeat"
    nbyte _f_lcomma
1:
    nbyte _f_lit, 0, _f_lload
    nbyte _f_run
    nbyte _f_jif, 1b

    nbyte _f_return
enddef _f_repeat

defword _f_count, "count"
    nbyte _f_lcomma, _f_lcomma
    nbyte _f_lit, 0, _f_lcomma
1:
    nbyte _f_lit, 2, _f_lload
    nbyte _f_lit, 1, _f_lload
    nbyte _f_sub, _f_eqz, _f_jif, 2f
    nbyte _f_lit, 2, _f_lload
    nbyte _f_lit, 0, _f_lload, _f_run
    nbyte _f_lit, 2, _f_lload
    nbyte _f_lit, 1, _f_add
    nbyte _f_lit, 2, _f_lstore
    nbyte _f_jump, 1b
2:
    nbyte _f_return
enddef _f_count

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

defword _f_here, "here"
    nbyte _f_of_here, _f_load
    nbyte _f_return
enddef _f_here

defword _f_allot, "allot"
    nbyte _f_of_here, _f_add_store
    nbyte _f_return
enddef _f_allot

defword _f_test, "_test"
    str "Hello, world!"
    nbyte _f_s_dot
    nbyte _f_lit, '\n', _f_sys_putchar
    nbyte _f_return
enddef _f_test

defword _f_init, "_init"
    nbyte _f_test
    nbyte _f_sys_exit
enddef _f_init

    .set _last_word, 1001b

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

    .balign 4096
data_stack:
    .zero 4096
return_stack:
    .zero 4096
allot_space:
    .zero 4096 * 4

    .section .note.GNU-stack, "", @progbits
