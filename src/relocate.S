#include "fiveth_defs.h"
#include "elf_defs.h"

    .section .text

    .global _do_relocate
func _do_relocate
    addi sp, sp, - ALIGN(3 * NATIVE)
    sn ra, (0 * NATIVE)(sp)
    sn s0, (1 * NATIVE)(sp)
    sn s1, (2 * NATIVE)(sp)

    lla t0, _DYNAMIC

    li s0, 0
    li s1, 0
    li a0, 0
    li a1, 0

1:
    ln t1, (0 * NATIVE)(t0)
    ln t2, (1 * NATIVE)(t0)
    beqz t1, .Lfound_dt_null
    addi t0, t0, 2 * NATIVE

    li t3, DT_RELA
    beq t1, t3, .Lfound_dt_rela

    li t3, DT_RELASZ
    beq t1, t3, .Lfound_dt_relasz

    li t3, DT_RELR
    beq t1, t3, .Lfound_dt_relr

    li t3, DT_RELRSZ
    beq t1, t3, .Lfound_dt_relrsz

    j 1b

.Lfound_dt_rela:
    mv s0, t2
    j 1b

.Lfound_dt_relasz:
    mv s1, t2
    j 1b

.Lfound_dt_relr:
    mv a0, t2
    j 1b

.Lfound_dt_relrsz:
    mv a1, t2
    j 1b

.Lfound_dt_null:

    sub a2, a2, t0
    beqz a1, 1f
    lla a2, __executable_start - START_ADDR
    call _do_relr
1:

    beqz s1, 1f
    mv a0, s0
    mv a1, s1
    lla a2, __executable_start - START_ADDR
    call _do_rela
1:

    ln ra, (0 * NATIVE)(sp)
    ln s0, (1 * NATIVE)(sp)
    ln s1, (2 * NATIVE)(sp)
    addi sp, sp, ALIGN(3 * NATIVE)
    ret
endfunc _do_relocate

    // void _do_relr(void *relr, size_t relrsz, size_t offset)
func _do_relr
    add a0, a0, a2
    add a1, a1, a0
    li t0, -1
1:
    beq a0, a1, 20f
    ln a4, (a0) // size_t entry
    addi a0, a0, NATIVE
    andi a3, a4, 1
    beqz a3, 10f
    // Bitmap: Relocate next (XLEN - 1) words
    mv t1, t0 // size_t *current = addr;
    addi t0, t0, NATIVE * (8 * NATIVE - 1)
2:
    srli a4, a4, 1  // Shift right, current is LSB
    beqz a4, 1b     // If all zeros, done with current entry
    andi a3, a4, 1  // Check current bit
    beqz a3, 3f
    // Relocate: *current += offset
    ln a3, (t1)
    add a3, a3, a2
    sn a3, (t1)
3:
    addi t1, t1, NATIVE // Bump current
    j 2b
10:
    // Address:
    // *(size_t *)(offset + entry) += offset
    add a4, a4, a2
    ln a3, (a4)
    add a3, a3, a2
    sn a3, (a4)
    addi t0, a4, NATIVE
    j 1b

20:
    ret
endfunc _do_relr

    // void _do_rela(void *relr, size_t relrsz, size_t offset)
func _do_rela
    add a0, a0, a2
    add a1, a1, a0
1:
    beq a0, a1, 10f
    ln t0, (0 * NATIVE)(a0)
    ln t1, (1 * NATIVE)(a0)
    ln t2, (2 * NATIVE)(a0)
    addi a0, a0, 3 * NATIVE
    li a3, R_RISCV_RELATIVE
    bne t1, a3, 1b

    add t0, t0, a2
    add t2, t2, a2
    sn t2, (t0)

    j 1b

10:
    ret
endfunc _do_rela
