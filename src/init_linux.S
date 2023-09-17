#include "fiveth_defs.h"

    .section .text.entry, "ax", @progbits

    .global _start
func _start
    .option push
    .option norelax
    lla gp, __global_pointer$
    .option pop

    call _do_relocate

    addi sp, sp, - ALIGN(info_size * NATIVE)
    mv a0, sp
    lla a1, init_word
    lla a2, data_stack
    lla a3, return_stack
    call fiveth_init_info

    lla a0, allot_space
    call fiveth_init_base

    mv a0, sp
    lla a1, allot_space
    call fiveth_run

    li a0, 0
    li a7, 93
    ecall
    unimp
endfunc _start

    .section .bss
    .p2align LGNATIVE
data_stack:
    .zero 4096
return_stack:
    .zero 4096
allot_space:
    .zero 4096 * 1024

    .section .note.GNU-stack, "", @progbits
