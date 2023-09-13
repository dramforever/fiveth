#include "fiveth_defs.h"

    .section .text

    .global _start
func _start
    .option push
    .option norelax
    lla gp, __global_pointer$
    .option pop
    la a0, data_stack
    la a1, return_stack
    la a2, allot_space
    tail fiveth_main
endfunc _start

    .global exit
func exit
    li a7, 94   // __NR_exit_group
    ecall
    unimp
endfunc exit

    .global getchar
func getchar
    addi sp, sp, - ALIGN(1)
    li a7, 63   // __NR_read
    li a0, 0    // int fd = stdin
    mv a1, sp   // char *buf
    li a2, 1    // size_t count
    ecall
    li a1, -1
    li a2, 1
    blt a0, a2, 1f
    lbu a1, (sp)
1:
    mv a0, a1
    addi sp, sp, ALIGN(1)
    ret
endfunc getchar

    .global putchar
func putchar
    addi sp, sp, - ALIGN(1)
    sb a0, (sp)
    li a7, 64   // __NR_write
    li a0, 1    // int fd = stdout
    mv a1, sp   // char *buf
    li a2, 1    // size_t count
    ecall
    // Error ignored, is this okay?
    addi sp, sp, ALIGN(1)
    ret
endfunc putchar

    .section .bss
    .p2align LGNATIVE
data_stack:
    .zero 4096
return_stack:
    .zero 4096
allot_space:
    .zero 4096 * 1024

    .section .note.GNU-stack, "", @progbits
