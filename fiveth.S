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

    .macro defword label, name, link=1001b
        _newword \label, "\name", _code_rundef, \link
    .endm

    .macro enddef label
        .size \label, . - \label
    .endm

    .section .rodata

    // First word in the linked list requires link = -1
codeword _f_return, "return", -1
    addi s_rsp, s_rfp, -2 * NATIVE
    ln s_rfp, (0 * NATIVE)(s_rsp)
    ln s_ip, (1 * NATIVE)(s_rsp)
    go
endcode _f_return

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

codeword _f_load, "@"
    ln a0, (-1 * NATIVE)(s_dsp)
    ln a0, (a0)
    sn a0, (-1 * NATIVE)(s_dsp)
    next
endcode _f_load

codeword _f_store, "!"
    addi s_dsp, s_dsp, -2 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    sn a0, (a1)
    next
endcode _f_store

codeword _f_bkpt, "bkpt"
    ebreak
    next
endcode _f_bkpt

codeword _f_lit, "_lit"
    ln a0, (1 * NATIVE)(s_ip)
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    addi s_ip, s_ip, 2 * NATIVE
    go
endcode _f_lit

defword _f_dup, "dup"
    nbyte _f_lcomma
    nbyte _f_lit, 0, _f_lload
    nbyte _f_lit, 0, _f_lload
    nbyte _f_return
enddef _f_dup

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

defword _f_test, "_test"
    nbyte _f_lit, 3
    nbyte _f_lit, 4
    nbyte _f_over, _f_over, _f_dup
    nbyte _f_bkpt
    nbyte _f_return
enddef _f_test

defword _f_init, "_init"
    nbyte _f_test
enddef _f_init

    .section .text

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

func _code_runraw
    addi s_ip, s_ip, NATIVE
    enter_frame
    addi s_dsp, s_dsp, - NATIVE
    ln s_ip, (s_dsp)
    go
endfunc _code_runraw

    .global main
func main
    la s_dsp, data_stack
    la s_rsp, return_stack
    mv s_rfp, s_rsp
    la s_ip, _f_init + o_payload
    go
endfunc main

    .section .bss

    .balign 4096
data_stack:
    .zero 4096
return_stack:
    .zero 4096

    .section .note.GNU-stack, "", @progbits
