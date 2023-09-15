#include "fiveth_defs.h"

    .section .text.entry, "ax", @progbits

    .global _start
func _start
    .option push
    .option norelax
    lla gp, __global_pointer$
    .option pop

    call _do_relocate

    la a0, data_stack
    la a1, return_stack
    la a2, allot_space
    tail fiveth_main
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
