#include "fiveth_defs.h"

    .section .text

    .global main
func main
    addi sp, sp, - ALIGN(6 * NATIVE)
    sn ra, (0 * NATIVE)(sp)
    sn s_dsp, (1 * NATIVE)(sp)
    sn s_ip, (2 * NATIVE)(sp)
    sn s_rsp, (3 * NATIVE)(sp)
    sn s_rfp, (4 * NATIVE)(sp)
    sn s_info, (4 * NATIVE)(sp)

    lla s_dsp, data_stack_end
    lla s_rsp, return_stack_end
    mv s_rfp, s_rsp
    lla s_info, info_struct
    lla s_ip, w_init_program
    ln a0, (s_ip)
    jr a0

exit_main:
    li a0, 0

    ln ra, (0 * NATIVE)(sp)
    ln s_dsp, (1 * NATIVE)(sp)
    ln s_ip, (2 * NATIVE)(sp)
    ln s_rsp, (3 * NATIVE)(sp)
    ln s_rfp, (4 * NATIVE)(sp)
    ln s_info, (5 * NATIVE)(sp)
    addi sp, sp, ALIGN(6 * NATIVE)
    ret
end main

    // Utilities

    // int memcmp(const void *s1, const void *s2, size_t n);
func memcmp
    beqz a2, 2f
    add a2, a0, a2
1:
    lbu a4, (a0)
    lbu a5, (a1)
    bne a4, a5, 3f
    addi a0, a0, 1
    addi a1, a1, 1
    bne a0, a2, 1b
2:
    li a0, 0
    ret
3:
    sub a0, a4, a5
    ret
end memcmp

    // size_t strlen(const char *s);
func strlen
    mv a4, a0
1:
    lb a5, (a0)
    addi a0, a0, 1
    bnez a5, 1b

    sub a0, a0, a4
    addi a0, a0, -1
    ret
end strlen

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

func do_dyn_call # Operand: list
    ln a0, (1 * NATIVE)(s_ip)
    ln a1, o_payload(a0)
    beqz a1, 10f // Is undefined yet?

    // Patch into do_call
    lla a2, do_call
    sn a2, (0 * NATIVE)(s_ip)
    sn a1, (1 * NATIVE)(s_ip)

    // If tail, patch into do_tail instead
    ln a2, (2 * NATIVE)(s_ip)
    lla a3, do_endlist
    lla a4, do_tail
    bne a2, a3, 1f
    sn a4, (0 * NATIVE)(s_ip)
1:

    addi s_ip, s_ip, 2 * NATIVE
    enter_frame
    mv s_ip, a1
    go

10:
    addi s_dsp, s_dsp, -1 * NATIVE
    sn a0, (s_dsp)
    addi s_ip, s_ip, 2 * NATIVE
    enter_frame
    lla s_ip, w_undef_dyn
    go
end do_dyn_call

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
        .size \label, \label\()_end - \label
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

    .macro defspecial name, comp
        mk_link
        mk_name "\name"
        nbyte \comp
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

    .macro _litzs str
        .pushsection .rodata.str1.1, "aMS", @progbits, 1
object litzs_\@
        .string "\str"
end litzs_\@
        .popsection
        _lit litzs_\@
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

defcode do_bkpt, "bkpt"
    ebreak
endcode do_bkpt

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

defcode do_prim_alloca, "__prim_alloca"
    ln a0, (s_dsp)
    sub s_rsp, s_rsp, a0
    andi s_rsp, s_rsp, -NATIVE
    sn s_rsp, (s_dsp)
    next
endcode do_prim_alloca

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

defcode do_dsp, "dsp"
    mv a0, s_dsp
    addi s_dsp, s_dsp, -1 * NATIVE
    sn a0, (s_dsp)
    next
endcode do_dsp

defcode do_of_info, "=info"
    addi s_dsp, s_dsp, -1 * NATIVE
    sn s_info, (s_dsp)
    next
endcode do_of_info

defcode do_strlen, "strlen"
    ln a0, (s_dsp)
    call strlen
    sn a0, (s_dsp)
    next
endcode do_strlen

defcode do_memcmp, "memcmp"
    ln a0, (2 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    ln a2, (0 * NATIVE)(s_dsp)
    call memcmp
    addi s_dsp, s_dsp, 2 * NATIVE
    sn a0, (s_dsp)
    next
endcode do_memcmp

defcode do_memcpy, "memcpy"
    ln a0, (2 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    ln a2, (0 * NATIVE)(s_dsp)
    call memcpy
    addi s_dsp, s_dsp, 3 * NATIVE
    next
endcode do_memcpy

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
endcode do_puts

defcode do_putchar, "putchar"
    ln a0, (s_dsp)
    call putchar
    addi s_dsp, s_dsp, 1 * NATIVE
    next
endcode do_putchar

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

def w_last_word, "last_word"
    _lit info_last ; _ info_load
enddef w_last_word

def w_dup, "dup"
    _p lcomma ; _lload 0 ; _lload 0
enddef w_dup

def w_drop, "drop"
    _p lcomma
enddef w_drop

def w_nip, "nip"
    _p lcomma ; _p lcomma ; _lload 0
enddef w_nip

def w_over, "over"
    _p lcomma ; _p lcomma
    _lload 1 ; _lload 0 ; _lload 1
enddef w_over

def w_swap, "swap"
    _p lcomma ; _p lcomma
    _lload 0 ; _lload 1
enddef w_swap

def w_pdup, "pdup"
    _p lcomma ; _p lcomma
    _lload 1 ; _lload 0 ; _lload 1 ; _lload 0
enddef w_pdup

def w_pdrop, "pdrop"
    _p lcomma ; _p lcomma
enddef w_pdrop

def w_ifelse, "ifelse"
    _p select ; _p tailrun
enddef w_ifelse

def w_info_load, "info@"
    _p of_info ; _p add ; _p load
enddef w_info_load

def w_info_store, "info!"
    _p of_info ; _p add ; _p store
enddef w_info_store

def w_brk, "brk"
    _lit info_brk ; _ info_load
enddef w_brk

def w_brk_store, "brk!"
    _lit info_brk ; _ info_store
enddef w_brk_store

def w_brk_add_store, "brk+!"
    _ brk ; _p add ; _ brk_store
enddef w_brk_add_store

def w_sbrk, "sbrk"
    _ brk ; _ swap ; _ brk_add_store
enddef w_sbrk

def w_brk_copy, "brk_copy"
    _p lcomma ; _p lcomma
    _lload 0 ; _ sbrk
    _ dup ; _lload 1 ; _lload 0 ; _p memcpy
enddef w_brk_copy

def w_zs_copy, "zs_copy"
    _p lcomma ; _p lcomma
    _lload 0 ; _lit 1 ; _p add ; _ sbrk
    _ dup ; _lload 1 ; _lload 0 ; _p memcpy
    _ dup ; _lload 0 ; _p add ; _lit 0 ; _ swap ; _p b_store
enddef w_zs_copy

def w_brk_align, "brk_align"
    _ brk
    _lit NATIVE - 1 ; _p add
    _lit - NATIVE ; _p and
    _ brk_store
enddef w_brk_align

def w_alloca, "alloca"
    _ swap ; _p prim_alloca ; _ swap
    _p run // Not tailrun here
enddef w_alloca

def w_error, "error"
    _p bkpt // TODO
enddef w_error

def w_u_dump, "_dump" // ( p -- )
    _ pdup ; _p eq
    list 101
        _ pdrop
    endlist 101, 201, w_u_dump
    list 101
        _lit NATIVE ; _p sub
        _ dup ; _p load ; _p print
        _tail u_dump
    endlist 101, 201, w_u_dump
    _tail ifelse
enddef w_u_dump

def w_dump, "dump"
    _lit '(' ; _p putchar
    _lit ' ' ; _p putchar
    _p dsp ; _lit data_stack_end ; _ u_dump
    _lit ')' ; _p putchar
    _lit '\n' ; _p putchar
enddef w_dump

def w_s_dot, "s."
    _ dup
    list 101
        _ over ; _p b_load_u ; _p putchar
        _lit 1 ; _p sub
        _ swap ; _lit 1 ; _p add ; _ swap
        _tail s_dot
    endlist 101, 201, w_s_dot_end
    list 101
        _ pdrop
    endlist 101, 201, w_s_dot_end
    _tail ifelse
enddef w_s_dot

def w_zs_dot, "zs."
    _ dup ; _p strlen ; _ s_dot
enddef w_zs_dot

def w_lx_show, "lx.show"
    _p lcomma
    _lload 0 ; _lit lx_istr ; _p add ; _p load
    _lload 0 ; _lit lx_ipos ; _p add ; _p load
    _ over ; _p sub ; _ s_dot

    _lit '<' ; _p putchar
    _lit '<' ; _p putchar
    _lit '<' ; _p putchar

    _lload 0 ; _lit lx_ipos ; _p add ; _p load
    _lload 0 ; _lit lx_iend ; _p add ; _p load
    _ over ; _p sub ; _ s_dot

    _lit '\n' ; _p putchar
enddef w_lx_show

def w_lx_input_store, "lx.input!"
    _p lcomma ; _p lcomma ; _p lcomma
    _lload 1 ; _lload 2 ; _lit lx_ipos ; _p add ; _p store
    _lload 1 ; _lload 2 ; _lit lx_istr ; _p add ; _p store

    _lload 1 ; _lload 0 ; _p add
    _lload 2 ; _lit lx_iend ; _p add ; _p store
enddef w_lx_input_store

def w_lx_buf_store, "lx.buf!"
    _p lcomma ; _p lcomma ; _p lcomma
    _lload 1 ; _lload 2 ; _lit lx_ppos ; _p add ; _p store
    _lload 1 ; _lload 2 ; _lit lx_pbuf ; _p add ; _p store

    _lload 1 ; _lload 0 ; _p add
    _lload 2 ; _lit lx_pend ; _p add ; _p store
enddef w_lx_buf_store

def w_lx_mark, "lx.mark"
    _ dup ; _lit lx_ppos ; _p add ; _p load
    _ swap ; _lit lx_last ; _p add ; _p store
enddef w_lx_mark

def w_lx_append_imm, "lx.append_imm"
    _ swap ; _p lcomma
    _lload 0 ; _lit lx_ppos ; _p add ; _p load
    _ dup ; _lit NATIVE ; _p add ; _lload 0 ; _lit lx_ppos ; _p add ; _p store
    _p store
enddef w_lx_append_imm

def w_lx_append, "lx.append"
    _ over ; _ lx_mark ; _ lx_append_imm
enddef w_lx_append

def w_lx_word, "lx.word"
    _p lcomma
    _lload 0 ; _lit lx_ipos ; _p add ; _p load
    _ dup ; _ skip_word
    _ dup ; _lload 0 ; _lit lx_ipos ; _p add ; _p store
    _ over ; _p sub
enddef w_lx_word

def w_lx_tail, "lx.tail"
    _lit lx_last ; _p add ; _p load
    _ dup ; _p eqz
    list 101
        _ drop
    endlist 101, 201, w_lx_tail_end
    list 101
        _ dup ; _p load ; _lit do_call + 1 ; _p eq
        list 102
            _ dup ; _lit do_tail + 1 ; _ swap ; _p store
        endlist 102, 202, 201f
        list 102
        endlist 102, 202, 201f
        _ ifelse
        _ dup ; _p load ; _lit do_run ; _p eq
        list 102
            _ dup ; _lit do_tailrun ; _ swap ; _p store
        endlist 102, 202, 201f
        list 102
        endlist 102, 202, 201f
        _ ifelse
        _ drop
    endlist 101, 201, w_lx_tail_end
    _tail ifelse
enddef w_lx_tail

def w_comp_call, "_comp_call"
    _ over ; _lit do_call + 1 ; _ lx_append
    _lit o_payload ; _p add ; _p load ; _tail lx_append_imm
enddef w_comp_call

def w_comp_prim, "_comp_prim"
    _lit o_payload ; _p add ; _p load ; _tail lx_append
enddef w_comp_prim

def w_comp_dyn, "_comp_dyn"
    _ over ; _lit do_dyn_call + 1; _ lx_append
    _ lx_append_imm
enddef w_comp_dyn

def w_undef_dyn, "_undef_dyn"
    _litzs "Word " ; _ zs_dot
    _lit o_name ; _p add ; _p load ; _ zs_dot
    _litzs " called before definition" ; _ zs_dot
    _lit '\n' ; _p putchar
    _ error
enddef w_undef_dyn

def w_add_entry, "add_entry"
    _ last_word ; _ over ; _lit o_link ; _p add ; _p store
    _lit info_last ; _ info_store
enddef w_add_entry

def w_comp_fn, "_comp_fn"
    _ drop ; _ dup ; _ lx_word
    _ zs_copy
    _ brk_align ; _lit 4 * NATIVE ; _ sbrk ; _p lcomma
    _lload 0 ; _lit o_name ; _p add ; _p store
    _lit w_comp_dyn ; _lload 0 ; _lit o_comp ; _p add ; _p store
    _lit 0 ; _lload 0 ; _lit o_payload ; _p add ; _p store
    _lload 0 ; _ add_entry

    _ dup ; _lit do_lit + 1 ; _ lx_append
    _lload 0 ; _ lx_append_imm
enddef w_comp_fn

defspecial "fn:", w_comp_fn

def w_comp_open_bracket, "_comp_open_bracket"
    _ drop ; _p lcomma
    _lit 0 ; _lload 0 ; _lit lx_last ; _p add ; _p store
    _lload 0 ; _lit lx_ppos ; _p add ; _p load
    _lload 0 ; _lit lx_listptr ; _p add ; _p load
    _lload 0 ; _ swap ; _ lx_append_imm
    _lload 0 ; _lit lx_listptr ; _p add ; _p store
enddef w_comp_open_bracket

defspecial "[", w_comp_open_bracket

def w_comp_close_bracket, "_comp_close_bracket"
    _ drop
    _ dup ; _ lx_is_top
    list 101
        _litzs "Unmatched closing bracket" ; _ zs_dot
        _lit '\n' ; _p putchar
        _ lx_show
        _ error
    endlist 101, 201, w_comp_close_bracket_end
    list 101
        _p lcomma
        _lload 0 ; _ lx_tail
        _lload 0 ; _lit do_endlist ; _ lx_append
        _lload 0 ; _lit 0 ; _ lx_append_imm
        _lload 0 ; _lit 0 ; _ lx_append_imm // TODO backtrace information
        _lload 0 ; _lit lx_listptr ; _p add ; _p load
        _ dup ; _p load ; _lload 0 ; _lit lx_listptr ; _p add ; _p store
        _lload 0 ; _lit lx_ppos ; _p add ; _p load
        // ( begin end )
        _ over ; _lload 0 ; _lit lx_ppos ; _p add ; _p store
        _ swap ; _lit NATIVE ; _p add ; _ swap
        _ brk_align
        _ over ; _p sub ; _ brk_copy
        _lload 0 ; _lit do_lit + 1 ; _ lx_append
        _lload 0 ; _ swap ; _ lx_append_imm
    endlist 101, 201, w_comp_close_bracket_end
    _tail ifelse
enddef w_comp_close_bracket

defspecial "]", w_comp_close_bracket

def w_define, "define"
    _ swap
    _ dup ; _lit o_comp ; _p add ; _p load
    _lit w_comp_dyn ; _p eq
    list 101
        _p lcomma
        _lload 0 ; _lit o_payload ; _p add ; _p store
        _lit w_comp_call ; _lload 0 ; _lit o_comp ; _p add ; _p store
    endlist 101, 201, w_define_end
    list 101
        _ error
    endlist 101, 201, w_define_end
    _ ifelse
enddef w_define

def w_is_space, "?space"
    _lit 0
    _ over ; _lit ' '; _p eq ; _p or
    _ over ; _lit '\t'; _p eq ; _p or
    _ nip
enddef w_is_space

def w_is_sigil, "?sigil"
    _lit 0
    _ over ; _lit ':'; _p eq ; _p or
    _ over ; _lit '"'; _p eq ; _p or
    _ nip
enddef w_is_sigil

def w_skip_space, "skip_space"
    _ dup ; _p b_load_u ; _ is_space
    list 101
        _lit 1 ; _p add ; _tail skip_space
    endlist 101, 201, w_skip_space_end
    list 101
        // Done
    endlist 101, 201, w_skip_space_end
    _tail ifelse
enddef w_skip_space

def w_u_lookup, "_lookup" // ( p:name n:name p:entry -- p:entry )
    _ dup ; _p eqz
    list 101
        // End of dictionary, lookup failure
        _ nip ; _ nip
    endlist 101, 201, w_u_lookup_end
    list 101
        _ pdup ; _lit o_name ; _p add ; _p load ; _p strlen ; _p eq
        list 102
            // Name length matches
            _p lcomma ; _p lcomma ; _p lcomma
            _lload 2 ; _lload 1 ; _lload 0
            _lload 2
            _lload 0 ; _lit o_name ; _p add ; _p load
            _lload 1 ; _p memcmp ; _p eqz
            list 103
                // Name matches
                _ nip ; _ nip
            endlist 103, 203, 202f
            list 103
                // Not a match, try next
                _lit o_link ; _p add ; _p load ; _tail u_lookup
            endlist 103, 203, 202f
            _tail ifelse
        endlist 102, 202, 201f
        list 102
            // Not a match, try next
            _lit o_link ; _p add ; _p load ; _tail u_lookup
        endlist 102, 202, 201f
        _tail ifelse
    endlist 101, 201, w_u_lookup_end
    _tail ifelse
enddef w_u_lookup

def w_lookup, "lookup"
    _ last_word ; _tail u_lookup
enddef w_lookup

def w_skip_word, "skip_word"
    _ dup ; _p b_load_u
    _ dup ; _ is_space ; _ swap ; _p eqz ; _p or
    list 101
    endlist 101, 201, w_skip_word_end
    list 101
        _ dup ; _p b_load_u
        _ swap ; _lit 1 ; _p add ; _ swap
        _ is_sigil
        list 102
        endlist 102, 202, 201f
        list 102
            _tail skip_word
        endlist 102, 202, 201f
        _tail ifelse
    endlist 101, 201, w_skip_word_end
    _tail ifelse
enddef w_skip_word

def w_lx_run, "lx.run"
    _p lcomma
    _lload 0 ; _lit do_endlist ; _ lx_append
    _lload 0 ; _lit 0 ; _ lx_append_imm
    _lload 0 ; _lit 0 ; _ lx_append_imm
    _lload 0 ; _lit lx_pbuf ; _p add ; _p load ; _p run
    _lload 0 ; _lit lx_pbuf ; _p add ; _p load
    _lload 0 ; _lit lx_ppos ; _p add ; _p store
enddef w_lx_run

def w_lx_is_top, "lx.?top"
    _lit lx_listptr ; _p add ; _p load ; _p eqz
enddef w_lx_is_top

def w_lx_check_run, "lx.check_run"
    _ dup ; _ lx_is_top
    list 101
        _p lcomma
        _ lx_run
        _lload 0
    endlist 101, 201, w_lx_check_run_end
    list 101
        _ drop
    endlist 101, 201, w_lx_check_run_end
    _tail ifelse
enddef w_lx_check_run

def w_lx_parse, "lx.parse"
    _ dup ; _lit lx_ipos ; _p add ; _p load
    _ skip_space
    _ dup ; _p b_load_u ; _lit 0 ; _p eq
    list 101
        _ pdrop
    endlist 101, 201, w_lx_parse_end
    list 101
        _p lcomma
        _lload 0 ; _ skip_word ; _p lcomma

        // Lookup current word
        _lload 0 ; _lload 1 ; _lload 0 ; _p sub ; _ lookup

        // Bump lx_ipos
        _ swap
        _lload 1
        _ over ; _lit lx_ipos ; _p add ; _p store
        _ swap

        _ dup
        list 102
            _ over ; _ swap
            _ dup ; _lit o_comp ; _p add ; _p load ; _p run
            _ dup ; _ lx_show
            _ dup ; _ lx_check_run
            _tail lx_parse
        endlist 102, 202, 201f
        list 102
            _ drop
            _litzs "Word not found:" ; _ zs_dot
            _lit '\n' ; _p putchar
            _ lx_show
            _ error
        endlist 102, 202, 201f
        _tail ifelse
    endlist 101, 201, w_lx_parse_end
    _tail ifelse
enddef w_lx_parse

def w_init_program, "_init_program"
    _lit 8 * NATIVE // FIXME: Parser struct size
    list 101
        _p lcomma
        _lload 0 ; _lit parse_buf ; _lit (parse_buf_end - parse_buf) ; _ lx_buf_store
        _lload 0 ; _lit something ; _ dup ; _p strlen ; _ lx_input_store
        _lit 0 ; _lload 0 ; _lit lx_listptr ; _p add ; _p store
        _lit 0 ; _lload 0 ; _lit lx_last ; _p add ; _p store
        _lload 0 ; _ lx_parse
    endlist 101, 201, w_init_program_end
    _ alloca
    _p exit
enddef w_init_program

    .set last_word, 1011b

    .section .data
object info_struct
    nbyte data_space
    nbyte data_space_end
    nbyte last_word
end info_struct

    .section .rodata
object something
    .string "fn:test [ dsp print test ] define [ test test ] [ run run ] [ ifelse ifelse ] [ ] dump error"
end something

    .section .bss
    .p2align LGNATIVE

object parse_buf
    .zero 4096
parse_buf_end:
end parse_buf

object data_stack
    .zero 4096
data_stack_end:
end data_stack

object return_stack
    .zero 4096
return_stack_end:
end return_stack

object data_space
    .zero 128 * 4096
data_space_end:
end data_space
