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
    add a2, sp, t0 // Data stack
    add a3, a2, t0 // Return stack
    add s0, a3, t0 // Allot space

    addi sp, sp, - ALIGN(6 * NATIVE)
    mv a0, sp
    la a1, init_word
    call fiveth_init_info

    mv a0, s0
    call fiveth_init_base

    mv a0, sp
    mv a1, s0
    call fiveth_run

    j _hang
endfunc _start

    .section .text
    .p2align 2
func _hang
1:
    wfi
    j 1b
endfunc _hang
