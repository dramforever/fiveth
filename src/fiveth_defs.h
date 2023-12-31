#ifndef _FIVETH_DEFS_H
#define _FIVETH_DEFS_H

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
#define s_info s4

// Stack alignment
#define ALIGN(offset) (((offset) + 0xf) & ~0xf)

    .macro func name
        .p2align 2
        .type \name, @function
\name:
    .endm

    .macro object name
        .type \name, @object
\name:
    .endm

    .macro end name
        .size \name, . - \name
    .endm

#define o_link (0 * NATIVE)
#define o_name (1 * NATIVE)
#define o_comp (2 * NATIVE)
#define o_payload (3 * NATIVE)

#define lx_ipos (0 * NATIVE)
#define lx_istr (1 * NATIVE)
#define lx_iend (2 * NATIVE)
#define lx_ppos (3 * NATIVE)
#define lx_pbuf (4 * NATIVE)
#define lx_pend (5 * NATIVE)
#define lx_listptr (6 * NATIVE)

#define info_brk (0 * NATIVE)
#define info_brk_lim (1 * NATIVE)
#define info_last (2 * NATIVE)

#endif /* _FIVETH_DEFS_H */
