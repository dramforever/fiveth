#include "fiveth_defs.h"

    .section .text.entry, "ax", @progbits

    .global _start
func _start
    .option push
    .option norelax
    lla gp, __global_pointer$
    .option pop

    lla sp, _end
    addi sp, sp, (1 << 10) + (1 << 10) - 1
    andi sp, sp, - (1 << 10)

    call _do_relocate

    la t0, _hang
    csrw stvec, t0

    li t0, 0x1000
    add a0, sp, t0 // Data stack
    add a1, a0, t0 // Return stack
    add a2, a1, t0 // Allot space
    tail fiveth_main
endfunc _start

    .section .text
    .p2align 2
func _hang
1:
    wfi
    j 1b
endfunc _hang
