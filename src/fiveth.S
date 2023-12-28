#include "fiveth_defs.h"

    .section .text

    .global main
func main
    addi sp, sp, - ALIGN(5 * NATIVE)
    sn ra, (0 * NATIVE)(sp)
    sn s_dsp, (1 * NATIVE)(sp)
    sn s_ip, (2 * NATIVE)(sp)
    sn s_rsp, (3 * NATIVE)(sp)
    sn s_rfp, (4 * NATIVE)(sp)

    lla s_dsp, data_stack_end
    lla s_rsp, return_stack_end
    mv s_rfp, s_rsp
    lla s_ip, w_init_program
    ln a0, (s_ip)
    jr a0
end main

func exit_main
    li a0, 0

    ln ra, (0 * NATIVE)(sp)
    ln s_dsp, (1 * NATIVE)(sp)
    ln s_ip, (2 * NATIVE)(sp)
    ln s_rsp, (3 * NATIVE)(sp)
    ln s_rfp, (4 * NATIVE)(sp)
    addi sp, sp, ALIGN(5 * NATIVE)
    ret
end exit_main

    .macro go
        ln a0, (s_ip)
        jr a0
    .endm

    .macro next
        addi s_ip, s_ip, NATIVE
        go
    .endm

    .macro enter_frame
        addi s_rsp, s_rsp, -2 * NATIVE
        sn s_rfp, (0 * NATIVE)(s_rsp)
        sn s_ip, (1 * NATIVE)(s_rsp)
        mv s_rfp, s_rsp
    .endm

    .section .text.code, "ax", @progbits

func do_call # Operand: list
    ln a0, (1 * NATIVE)(s_ip)
    addi s_ip, s_ip, 2 * NATIVE
    enter_frame
    mv s_ip, a0
    go
end do_call

func do_tail # Operand: list
    mv s_rsp, s_rfp
    ln s_ip, (1 * NATIVE)(s_ip)
    go
end do_tail

func do_endlist
    ln a0, (0 * NATIVE)(s_rfp)
    ln s_ip, (1 * NATIVE)(s_rfp)
    addi s_rsp, s_rfp, 2 * NATIVE
    mv s_rfp, a0
    go
end do_endlist

func do_lit # Operand: lit
    ln a0, (1 * NATIVE)(s_ip)
    addi s_dsp, s_dsp, -1 * NATIVE
    sn a0, (s_dsp)
    addi s_ip, s_ip, 2 * NATIVE
    go
end do_lit

    .section .rodata.words, "a", @progbits
    .p2align LGNATIVE

    .macro _startlist start
        .pushsection .rodata.list_\@, "a", @progbits
        .p2align LGNATIVE
\start:
    .endm

    .macro _endlist start, end, endref, parent
        nbyte do_endlist
\end:
        nbyte \endref - \start
        nbyte \parent
        .popsection
    .endm

    .macro mk_link link=1011b
        .set .Llink_\@, \link
1011:
        nbyte .Llink_\@
    .endm

    .macro mk_name name
        .pushsection .rodata.str1.1, "aMS", @progbits, 1
object str_\@
        .string "\name"
end str_\@

        .popsection

        nbyte str_\@
    .endm

    .macro def label, name, link=1011b
        mk_link \link
        mk_name "\name"
        nbyte w_comp_call
        nbyte \label
        _startlist \label
    .endm

    .macro enddef label
        _endlist \label, \label\()_end, \label\()_end, 0
    .endm

    .macro defcode label, name
        mk_link
        mk_name "\name"
        nbyte w_comp_prim
        nbyte \label
        .pushsection .text.code, "ax", @progbits
func \label
    .endm enddef

    .macro endcode label
end \label
        .popsection
    .endm

    .macro list start
        nbyte do_lit + 1, \start\()f
        _startlist \start
    .endm

    .macro endlist start, end, parent
        _endlist \start\()b, \end, \end\()b, \parent
    .endm

    .macro _p prim
        nbyte do_\prim
    .endm

    .macro _ list
        nbyte do_call + 1, w_\list
    .endm

    .macro _lit val
        nbyte do_lit + 1, \val
    .endm

    .macro _tail list
        nbyte do_tail + 1, w_\list
    .endm

    .macro _lload num
        _lit \num ; _p lload
    .endm

    // Some actual word definitions

def w_nop, "nop", 0
enddef w_nop

defcode do_run, "run"
    ln a0, (s_dsp)
    addi s_dsp, s_dsp, 1 * NATIVE
    addi s_ip, s_ip, 1 * NATIVE
    enter_frame
    mv s_ip, a0
    go
endcode do_run

defcode do_tailrun, "tailrun"
    mv s_rsp, s_rfp
    ln s_ip, (s_dsp)
    addi s_dsp, s_dsp, 1 * NATIVE
    go
endcode do_tailrun

defcode do_exit, "exit"
    addi s_dsp, s_dsp, 1 * NATIVE
    j exit_main
endcode do_exit

defcode do_lcomma, "l,"
    ln a0, (s_dsp)
    addi s_dsp, s_dsp, 1 * NATIVE
    addi s_rsp, s_rsp, -1 * NATIVE
    sn a0, (s_rsp)
    next
endcode do_lcomma

defcode do_lload, "l@"
    ln a0, (s_dsp)
    slli a0, a0, LGNATIVE
    sub a0, s_rfp, a0
    ln a0, (-1 * NATIVE)(a0)
    sn a0, (s_dsp)
    next
endcode do_lload

defcode do_print, "print"
    .pushsection .rodata.str1.1, "aMS", @progbits, 1
1:
    .string "0x%x "
    .popsection

    la a0, 1b
    ln a1, (0 * NATIVE)(s_dsp)
    call printf
    addi s_dsp, s_dsp, 1 * NATIVE
    next
endcode do_print

defcode do_puts, "puts"
    ln a0, (s_dsp)
    call puts
    addi s_dsp, s_dsp, 1 * NATIVE
    next
endcode do_print

    .macro unary label, name, insn
defcode \label, "\name"
        ln a0, (s_dsp)
        \insn
        sn a0, (s_dsp)
        next
endcode \label
    .endm

    .macro binary label, name, insn
defcode \label, "\name"
        ln a0, (1 * NATIVE)(s_dsp)
        ln a1, (0 * NATIVE)(s_dsp)
        \insn
        addi s_dsp, s_dsp, 1 * NATIVE
        sn a0, (s_dsp)
        next
endcode \label
    .endm

    unary do_neg, "neg", "neg a0, a0"
    unary do_not, "not", "not a0, a0"
    unary do_eqz, "=0", "seqz a0, a0"
    unary do_nez, "!=0", "snez a0, a0"

    // (Can't use ln in strings)
#if __riscv_xlen == 32
    unary do_load, "@", "lw a0, (a0)"
    unary do_w_load_u, "w@u", "lw a0, (a0)"
#else
    unary do_load, "@", "ld a0, (a0)"
    unary do_w_load_u, "w@u", "lwu a0, (a0)"
#endif

    unary do_w_load, "w@", "lw a0, (a0)"
    unary do_h_load, "h@", "lh a0, (a0)"
    unary do_h_load_u, "h@u", "lhu a0, (a0)"
    unary do_b_load, "b@", "lb a0, (a0)"
    unary do_b_load_u, "b@u", "lbu a0, (a0)"

    binary do_add, "+", "add a0, a0, a1"
    binary do_sub, "-", "sub a0, a0, a1"
    binary do_and, "&", "and a0, a0, a1"
    binary do_or, "|", "or a0, a0, a1"
    binary do_xor, "^", "xor a0, a0, a1"
    binary do_shl, "<<", "sll a0, a0, a1"
    binary do_shr, ">>", "srl a0, a0, a1"

    binary do_eq, "=", "xor a0, a0, a1 ; seqz a0, a0"
    binary do_ne, "!=", "xor a0, a0, a1 ; snez a0, a0"

    .macro store_like label, name, insn
defcode \label, "\name"
        ln a0, (1 * NATIVE)(s_dsp)
        ln a1, (0 * NATIVE)(s_dsp)
        \insn a0, (a1)
        addi s_dsp, s_dsp, 2 * NATIVE
        next
endcode \label
    .endm

    store_like do_store, "!", sn
    store_like do_w_store, "w!", sw
    store_like do_h_store, "h!", sh
    store_like do_b_store, "b!", sb

defcode do_select, "select"
    ln a0, (2 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    ln a2, (0 * NATIVE)(s_dsp)
    beqz a0, 1f
    mv a2, a1
1:

    addi s_dsp, s_dsp, 2 * NATIVE
    sn a2, (s_dsp)
    next
endcode do_select

def w_dup, "dup"
    _p lcomma ; _lload 0 ; _lload 0
enddef w_dup

def w_drop, "drop"
    _p lcomma
enddef w_drop

def w_ifelse, "ifelse"
    _p select ; _p tailrun
enddef w_ifelse

def w_comp_call, "_comp_call"
enddef w_comp_call

def w_comp_prim, "_comp_prim"
enddef w_comp_prim

def w_print_dict, "print_dict"
    _ dup ; _p nez
    list 101
        _ dup ; _lit (1 * NATIVE) ; _p add ; _p load ; _p puts
        _p load
        _tail print_dict
    endlist 101, 201, w_print_dict_end
    list 101
    endlist 101, 201, w_print_dict_end
    _tail ifelse
enddef w_print_dict

def w_init_program, "_init_program"
    _lit last_word ; _ print_dict
    _p exit
enddef w_init_program

    .set last_word, 1011b

    .section .bss
    .p2align LGNATIVE
object data_stack
    .zero 4096
data_stack_end:
end data_stack

object return_stack
    .zero 4096
return_stack_end:
end return_stack
