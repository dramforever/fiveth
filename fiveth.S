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

// Stack alignment
#define ALIGN(x) (((x) + 0xf) & ~0xf)

#define s_dsp s0
#define s_ip s1
#define s_rsp s2
#define s_rfp s3

    .macro defstring name, str
    .pushsection .rodata.str1.1, "aMS", @progbits, 1
\name:
    .string "\str"
    .popsection
    .endm

    .macro la_string rd, str
    defstring .Lstr_\@, "\str"
    la \rd, .Lstr_\@
    .endm

    .section .text

    // Basic I/O functions

    // void fiveth_putchar(char c);
    .type fiveth_putchar, @function
fiveth_putchar:
    addi sp, sp, - ALIGN(1 * NATIVE)
    sn ra, (sp)
    call putchar
    ln ra, (sp)
    addi sp, sp, ALIGN(1 * NATIVE)
    ln a0, stdout
    tail fflush
    .size fiveth_putchar, . - fiveth_putchar

    // int fiveth_getchar();
    .type fiveth_getchar, @function
fiveth_getchar:
    tail getchar
    .size fiveth_getchar, . - fiveth_getchar

    // Start here
    .global main
    .type main, @function
main:
    la a0, _last_word
    sn a0, last_word, a1
    la a0, allot_space
    sn a0, allot_pointer, a1

    la s_dsp, data_stack
    tail toplevel
    .size main, . - main

    // REPL starts here
    .type toplevel, @function
toplevel:
1:
    la s11, token_buf
    li s10, -1
    li a0, '>' ; call fiveth_putchar
2:
    li a0, ' ' ; call fiveth_putchar
    la a0, line_buf
    call fiveth_getline
    bltz a0, 10f // Exit on EOF
    mv a3, a0
    mv a0, s11
    mv a1, s10
    la a2, line_buf
    call parse_line
    not a2, a0
    beqz a2, 1b // Parse error
    not a2, a1
    bnez a2, 3f // Line continues

    la s_rsp, return_stack
    mv s_rfp, s_rsp
    la s_ip, token_buf
    ln a0, (s_ip)
    ln a0, (a0)
    jr a0
    unimp

3:
    mv s11, a0
    mv s10, a1
    li a0, '|' ; call fiveth_putchar
    j 2b

10:
    li a0, 0
    tail exit

    .size toplevel, . - toplevel

    // <void *, void *> parse_line(
    //      void **token_buf,
    //      void *back_fill,
    //      const char *line,
    //      size_t len
    // );
    // Returns:
    // - `a0`: `-1` if parse error, or new token buffer position
    // - `a1`: New `back_fill` pointer
    .type parse_line, @function
parse_line:
#define s_tok s0        // Token buffer pointer
#define s_wptr s1       // Start of token
#define s_wend s2       // End of word
#define s_eol s3        // End of line
#define s_lptr s4       // Length back-fill pointer
#define s_errmsg s5     // Error message

    addi sp, sp, -ALIGN(7 * NATIVE)
    sn ra, (0 * NATIVE)(sp)
    sn s_tok, (1 * NATIVE)(sp)
    sn s_wptr, (2 * NATIVE)(sp)
    sn s_wend, (3 * NATIVE)(sp)
    sn s_eol, (4 * NATIVE)(sp)
    sn s_lptr, (5 * NATIVE)(sp)
    sn s_errmsg, (6 * NATIVE)(sp)

    mv s_tok, a0
    mv s_lptr, a1
    mv s_wptr, a2
    add s_eol, s_wptr, a3
.Lparse_token:
1:
    beq s_eol, s_wptr, .Lline_done

    mv s_wend, s_wptr

    lbu a0, (s_wend)

    // Skip whitespace
    addi s_wptr, s_wptr, 1
    li a1, ' ' ; beq a0, a1, 1b
    li a1, '\t' ; beq a0, a1, 1b
    addi s_wptr, s_wptr, -1

    // Check special characters

    li a1, '[' ; beq a0, a1, .Lhandle_list
    li a1, ']' ; beq a0, a1, .Lhandle_ret
    li a1, '"' ; beq a0, a1, .Lhandle_string

    // Check for negative number
    addi a1, s_wend, 1
    beq a1, s_eol, 1f
    li a1, '-' ; bne a0, a1, 1f

    lbu a0, 1(s_wend)
    li a1, '0' ; bltu a0, a1, 1f
    li a1, '9' ; bgtu a0, a1, 1f

    li a4, -1
    addi s_wend, s_wend, 1
    j .Lhandle_number

1:

    // Check for positive number
    li a4, 0
    li a1, '0' ; bltu a0, a1, 1f
    li a1, '9' ; bleu a0, a1, .Lhandle_number

1:
    // Parse word
    beq s_wend, s_eol, .Lgot_token
    lbu a0, (s_wend)
    li a2, '[' ; beq a0, a2, .Lgot_token
    li a2, ']' ; beq a0, a2, .Lgot_token
    li a2, ' ' ; beq a0, a2, .Lgot_token
    li a2, '\t' ; beq a0, a2, .Lgot_token
2:
    // Not end of token, take character
    addi s_wend, s_wend, 1
    j 1b

.Lgot_token:
    mv a0, s_wptr
    sub a1, s_wend, s_wptr
    call find_word
    not a1, a0
    la_string s_errmsg, "Undefined word"
    beqz a1, .Lparse_error
    sn a0, (s_tok)
    addi s_tok, s_tok, NATIVE
    mv s_wptr, s_wend
    j .Lparse_token

    // List format: { list <n> ... ret }

.Lhandle_list:
    // Parse '['
    la a0, _f_litlist
    sn a0, (s_tok)
    // Push into refill linked list
    sn s_lptr, NATIVE(s_tok)
    addi s_tok, s_tok, NATIVE * 2
    mv s_lptr, s_tok
    addi s_wptr, s_wptr, 1
    j .Lparse_token

.Lhandle_ret:
    // Parse ']'

    // If s_lptr == -1 then there's a mismatch
    not a1, s_lptr
    la_string s_errmsg, "Mismatched closing bracket"
    beqz a1, .Lparse_error

    la a0, _f_return
    sn a0, (s_tok)
    addi s_tok, s_tok, NATIVE

    // Pop linked list and refill length
    mv a0, s_lptr
    ln s_lptr, (- NATIVE)(s_lptr)
    sub a1, s_tok, a0
    sn a1, (- NATIVE)(a0)

    addi s_wptr, s_wptr, 1
    j .Lparse_token

.Lhandle_string:
    // Skip opening quote
    addi s_wend, s_wend, 1
    la a0, _f_litstring
    sn a0, (s_tok)
    addi s_tok, s_tok, 2 * NATIVE
    mv a2, s_tok // Start of string
1:
    la_string s_errmsg, "Unterminated string"
    beq s_wend, s_eol, .Lparse_error
    lbu a0, (s_wend)
    addi s_wend, s_wend, 1
    li a1, '"' ; beq a0, a1, 2f
    sb a0, (s_tok)
    addi s_tok, s_tok, 1
    j 1b

2:
    // Store string length
    sub a3, s_tok, a2
    sn a3, (-1 * NATIVE)(a2)

    // Align token pointer
    addi s_tok, s_tok, NATIVE - 1
    andi s_tok, s_tok, ~ (NATIVE - 1)
    mv s_wptr, s_wend
    j .Lparse_token

.Lhandle_number:
    // a4 = 0 if no negative sign, -1 if negative sign
    sub a0, s_eol, s_wend
    li a1, 2
    bltu a0, a1, .Lhandle_decimal
    lbu a0, (s_wend)
    li a1, '0'
    bne a0, a1, .Lhandle_decimal
    lbu a0, 1(s_wend)
    li a1, 'x'
    bne a0, a1, .Lhandle_decimal

    // Hex
    li a1, 0
    addi s_wend, s_wend, 2 // Skip 0x prefix
1:
    beq s_wend, s_eol, .Lnumber_okay
    lbu a0, (s_wend)
    li a2, '0' ; bltu a0, a2, .Lend_number
    li a2, '9' ; bgtu a0, a2, 2f
    addi a0, a0, -'0'
    j 3f

2:
    li a2, 'a' ; bltu a0, a2, .Lend_number
    li a2, 'f' ; bgtu a0, a2, .Lend_number
    addi a0, a0, - 'a' + 10

3:
    slli a1, a1, 4
    add a1, a1, a0
    addi s_wend, s_wend, 1
    j 1b

.Lhandle_decimal:
    li a1, 0
1:
    beq s_wend, s_eol, .Lnumber_okay
    lbu a0, (s_wend)
    li a2, '0' ; bltu a0, a2, .Lend_number
    li a2, '9' ; bgtu a0, a2, .Lend_number

    addi a0, a0, -'0'

    slli a3, a1, 3
    slli a1, a1, 1
    add a1, a1, a3
    add a1, a1, a0

    addi s_wend, s_wend, 1

    j 1b

.Lend_number:
    li a2, '[' ; beq a0, a2, .Lnumber_okay
    li a2, ']' ; beq a0, a2, .Lnumber_okay
    li a2, ' ' ; beq a0, a2, .Lnumber_okay
    li a2, '\t' ; bne a0, a2, .Linvalid_number

.Lnumber_okay:
    // Handle negative sign flag
    xor a1, a1, a4
    sub a1, a1, a4

    la a0, _f_lit
    sn a0, (s_tok)
    sn a1, NATIVE(s_tok)
    addi s_tok, s_tok, 2 * NATIVE
    mv s_wptr, s_wend
    j .Lparse_token

.Linvalid_number:
    la_string s_errmsg, "Invalid number"
    j .Lparse_error

.Lline_done:
    not a1, s_lptr
    mv a0, s_tok
    bnez a1, .Lparse_done // Continue line

    la a1, token_buf
    li a0, -1
    beq a1, s_tok, .Lparse_done // Empty line

    la a1, _f_ok
    sn a1, (s_tok)
    addi s_tok, s_tok, NATIVE
    mv a0, s_tok
    j .Lparse_done

.Lparse_error:
    addi s_wptr, s_wptr, 2  // Leave space for prompt
1:
    la a1, line_buf
    beq a1, s_wptr, 2f
    li a0, ' ' ; call fiveth_putchar
    addi s_wptr, s_wptr, -1
    j 1b
2:
    li a0, '^' ; call fiveth_putchar
    li a0, '\n' ; call fiveth_putchar
    mv a0, s_errmsg
    call fiveth_puts
    li a0, -1 // Indicate parse error

.Lparse_done:
    mv a1, s_lptr
    ln ra, (0 * NATIVE)(sp)
    ln s_tok, (1 * NATIVE)(sp)
    ln s_wptr, (2 * NATIVE)(sp)
    ln s_wend, (3 * NATIVE)(sp)
    ln s_eol, (4 * NATIVE)(sp)
    ln s_lptr, (5 * NATIVE)(sp)
    ln s_errmsg, (6 * NATIVE)(sp)
    addi sp, sp, ALIGN(7 * NATIVE)
    ret

#undef s_tok
#undef s_wptr
#undef s_wend
#undef s_eol
#undef s_lptr
#undef s_errmsg

    .size parse_line, . - parse_line

    .type fiveth_puts, @function
fiveth_puts:
    addi sp, sp, - ALIGN(2 * NATIVE)
    sn ra, (0 * NATIVE)(sp)
    sn s0, (1 * NATIVE)(sp)
    mv s0, a0
1:
    lbu a0, (s0)
    beqz a0, 2f
    call putchar
    addi s0, s0, 1
    j 1b
2:
    li a0, '\n'
    call putchar
    ln ra, (0 * NATIVE)(sp)
    ln s0, (1 * NATIVE)(sp)
    addi sp, sp, ALIGN(2 * NATIVE)
    ret
    .size fiveth_puts, . - fiveth_puts

    .type fiveth_getline, @function
fiveth_getline:
    addi sp, sp, - ALIGN(3 * NATIVE)
    sn ra, (0 * NATIVE)(sp)
    sn s0, (1 * NATIVE)(sp)
    sn s1, (2 * NATIVE)(sp)
    mv s0, a0
    mv s1, a0
1:
    call fiveth_getchar
    bltz a0, 2f
    li a1, '\n' ; beq a0, a1, 3f
    li a1, '\r' ; beq a0, a1, 3f
    sb a0, (s1)
    addi s1, s1, 1
    j 1b

2:
    sub a0, s1, s0
    // If read nothing return -1
    seqz a1, a0
    sub a0, a0, a1
    j 10f

3:
    sub a0, s1, s0

10:
    ln ra, (0 * NATIVE)(sp)
    ln s0, (1 * NATIVE)(sp)
    ln s1, (2 * NATIVE)(sp)
    addi sp, sp, ALIGN(3 * NATIVE)
    ret
    .size fiveth_getline, . - fiveth_getline

    // void putstring(const char *str, size_t len);
    .type putstring, @function
putstring:
    addi sp, sp, - ALIGN(NATIVE * 3)
    sn ra, (0 * NATIVE)(sp)
    sn s0, (1 * NATIVE)(sp)
    sn s1, (2 * NATIVE)(sp)
    mv s0, a0
    add s1, a0, a1
1:
    beq s0, s1, 2f
    lbu a0, (s0)
    call fiveth_putchar
    addi s0, s0, 1
    j 1b
2:
    ln ra, (0 * NATIVE)(sp)
    ln s0, (1 * NATIVE)(sp)
    ln s1, (2 * NATIVE)(sp)
    addi sp, sp, ALIGN(NATIVE * 3)
    ret
    .size putstring, . - putstring

#if __riscv_xlen == 64
    .pushsection .sdata, "aw", @progbits
.Ldiv10_const:
    .8byte 0xcccccccccccccccd
    .popsection
#endif

    // void print_decimal(size_t num);
    .type print_decimal, @function
print_decimal:
    addi sp, sp, - ALIGN(32 + NATIVE)
    sn ra, 32(sp)
#if __riscv_xlen == 64
    ld t0, .Ldiv10_const
#else
    li t0, 0xcccccccd
#endif

    addi a1, sp, 32
    mv t1, a0

    srai a2, a0, __riscv_xlen - 1
    xor a0, a0, a2
    sub a0, a0, a2
    // a0 = abs(num)
1:
    mulhu a2, a0, t0
    srli a2, a2, 3
    // a2 = a0 / 10
    slli a3, a2, 3
    slli a4, a2, 1
    add a3, a3, a4
    // a3 = (a0 / 10) * 10
    sub a3, a0, a3
    // a3 = a0 % 10
    addi a3, a3, '0'
    addi a1, a1, -1
    sb a3, (a1)

    mv a0, a2
    bnez a0, 1b

    bgez t1, 1f
    addi a1, a1, -1
    li a0, '-'
    sb a0, (a1)
1:

    mv a0, a1
    addi a1, sp, 32
    sub a1, a1, a0
    call putstring

    ln ra, 32(sp)
    addi sp, sp, ALIGN(32 + NATIVE)
    ret
    .size print_decimal, . - print_decimal

    // void print_hex(size_t num);
    .type print_hex, @function
print_hex:
    addi sp, sp, - ALIGN(NATIVE * 3)
    sn ra, (0 * NATIVE)(sp)
    sn s0, (1 * NATIVE)(sp)
    sn s1, (2 * NATIVE)(sp)

    mv s0, a0

    li a0, '0' ; call fiveth_putchar
    li a0, 'x' ; call fiveth_putchar

    li s1, (8 * NATIVE) - 4
1:
    srl a0, s0, s1
    andi a0, a0, 0xf
    li a1, 10
    blt a0, a1, 2f
    addi a0, a0, 'a' - '0' - 10
2:
    addi a0, a0, '0'
    call fiveth_putchar
    addi s1, s1, -4
    bgez s1, 1b

    ln ra, (0 * NATIVE)(sp)
    ln s0, (1 * NATIVE)(sp)
    ln s1, (2 * NATIVE)(sp)
    addi sp, sp, ALIGN(NATIVE * 3)

    .size print_hex, . - print_hex

#define o_code (0 * NATIVE)
#define o_link (1 * NATIVE)
#define o_name (2 * NATIVE)
#define o_nsize (3 * NATIVE)

    // void *find_word(const char *name, size_t len);
    .type find_word, @function
find_word:
    addi sp, sp, - ALIGN(NATIVE * 4)
    sn ra, (0 * NATIVE)(sp)
    sn s0, (1 * NATIVE)(sp)
    sn s1, (2 * NATIVE)(sp)
    sn s2, (3 * NATIVE)(sp)

    mv s0, a0
    mv s1, a1
    ln s2, last_word
1:
    li a0, -1
    beq s2, a0, 10f // Not found, return -1

    ln a2, o_nsize(s2)
    bne s1, a2, 2f

    ln a0, o_name(s2)
    mv a1, s0
    call memcmp
    beqz a0, 3f
2:
    ln s2, o_link(s2)
    j 1b

3:
    mv a0, s2
10:
    ln ra, (0 * NATIVE)(sp)
    ln s0, (1 * NATIVE)(sp)
    ln s1, (2 * NATIVE)(sp)
    ln s2, (3 * NATIVE)(sp)
    addi sp, sp, ALIGN(NATIVE * 4)
    ret

    .type memcmp, @function
memcmp:
1:
    beqz a2, 10f
    lb a3, (a0)
    lb a4, (a1)
    blt a3, a4, 11f
    bgt a3, a4, 12f

    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a2, -1
    j 1b

10:
    li a0, 0; ret
11:
    li a0, -1; ret
12:
    li a0, 1 ; ret
    .size memcmp, . - memcmp

    .type memcpy, @function
memcpy:
    add a2, a0, a2
1:
    beq a0, a2, 2f
    lb a3, (a1)
    sb a3, (a0)
    addi a0, a0, 1
    addi a1, a1, 1
    j 1b
2:
    ret
    .size memcpy, . - memcpy

    .macro go
    ln a0, (s_ip)
    ln a0, (a0)
    jr a0
    .endm

    .macro next
    addi s_ip, s_ip, NATIVE
    go
    .endm

    // Native code for words

.Lf_litlist:
    ln a0, (1 * NATIVE)(s_ip)
    addi a1, s_ip, NATIVE
    sn a1, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    add s_ip, s_ip, a0
    addi s_ip, s_ip, 2 * NATIVE
    go

.Lf_litstring:
    ln a0, (1 * NATIVE)(s_ip)
    addi a1, s_ip, 2 * NATIVE
    sn a1, (0 * NATIVE)(s_dsp)
    sn a0, (1 * NATIVE)(s_dsp)
    addi s_dsp, s_dsp, 2 * NATIVE
    // Align the length
    addi a0, a0, NATIVE - 1
    andi a0, a0, ~ (NATIVE - 1)
    add s_ip, s_ip, a0
    add s_ip, s_ip, 2 * NATIVE
    go

.Lf_jump:
    ln s_ip, (1 * NATIVE)(s_ip)
    go

.Lf_jif:
    addi s_dsp, s_dsp, - NATIVE
    ln a0, (s_dsp)
    addi s_ip, s_ip, 2 * NATIVE
    beqz a0, 1f
    ln s_ip, (-1 * NATIVE)(s_ip)
1:
    go

.Lf_nop:
    next

.Lf_lit:
    ln a0, NATIVE(s_ip)
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    addi s_ip, s_ip, 2 * NATIVE
    go

.Lf_dot:
    addi s_dsp, s_dsp, - NATIVE
    ln a0, (s_dsp)
    call print_decimal
    li a0, ' '
    call fiveth_putchar
    next

.Lf_sdot:
    addi s_dsp, s_dsp, - 2 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    call putstring
    next

.Lf_ok:
    la_string a0, " ok "
    li a1, 4
    call putstring
    la a0, data_stack
    sub a0, s_dsp, a0
    srai a0, a0, LGNATIVE
    call print_decimal
    li a0, '\n'
    call fiveth_putchar
    j toplevel

lf_constant:
    ln a0, (s_ip)
    ln a0, (4 * NATIVE)(a0)
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    next

.Lf_dup:
    ln a0, (-1 * NATIVE)(s_dsp)
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    next

.Lf_drop:
    addi s_dsp, s_dsp, - NATIVE
    next

.Lf_swap:
    ln a0, (-2 * NATIVE)(s_dsp)
    ln a1, (-1 * NATIVE)(s_dsp)
    sn a0, (-1 * NATIVE)(s_dsp)
    sn a1, (-2 * NATIVE)(s_dsp)
    next

.Lf_over:
    ln a0, (-2 * NATIVE)(s_dsp)
    sn a0, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    next

.Lf_rot:
    ln a0, (-3 * NATIVE)(s_dsp)
    ln a1, (-2 * NATIVE)(s_dsp)
    ln a2, (-1 * NATIVE)(s_dsp)
    sn a0, (-1 * NATIVE)(s_dsp)
    sn a1, (-3 * NATIVE)(s_dsp)
    sn a2, (-2 * NATIVE)(s_dsp)
    next

.Lf_dswap:
    ln a0, (-4 * NATIVE)(s_dsp)
    ln a1, (-3 * NATIVE)(s_dsp)
    ln a2, (-2 * NATIVE)(s_dsp)
    ln a3, (-1 * NATIVE)(s_dsp)
    sn a0, (-2 * NATIVE)(s_dsp)
    sn a1, (-1 * NATIVE)(s_dsp)
    sn a2, (-4 * NATIVE)(s_dsp)
    sn a3, (-3 * NATIVE)(s_dsp)
    next

    .macro enter_frame
    sn s_rfp, (0 * NATIVE)(s_rsp)
    sn s_ip, (1 * NATIVE)(s_rsp)
    addi s_rsp, s_rsp, 2 * NATIVE
    mv s_rfp, s_rsp
    .endm

.Lf_rawexecute:
    addi s_ip, s_ip, NATIVE
    enter_frame
    addi s_dsp, s_dsp, - NATIVE
    ln s_ip, (s_dsp)
    go

lf_definition:
    addi s_ip, s_ip, NATIVE
    enter_frame
    ln s_ip, (-1 * NATIVE)(s_ip)
    addi s_ip, s_ip, 4 * NATIVE
    go

.Lf_return:
    addi s_rsp, s_rfp, -2 * NATIVE
    ln s_rfp, (0 * NATIVE)(s_rsp)
    ln s_ip, (1 * NATIVE)(s_rsp)
    go

.Lf_lhere:
    sn s_rsp, (s_dsp)
    addi s_dsp, s_dsp, NATIVE
    next

.Lf_lallot:
    addi s_dsp, s_dsp, -1 * NATIVE
    ln a0, (s_dsp)
    add s_rsp, s_rsp, a0
    next

.Lf_nlallot:
    addi s_dsp, s_dsp, -1 * NATIVE
    ln a0, (s_dsp)
    slli a0, a0, LGNATIVE
    add s_rsp, s_rsp, a0
    next

.Lf_load_l:
    ln a0, (-1 * NATIVE)(s_dsp)
    slli a0, a0, LGNATIVE
    add a0, a0, s_rfp
    ln a0, (a0)
    sn a0, (-1 * NATIVE)(s_dsp)
    next

.Lf_store_l:
    addi s_dsp, s_dsp, -2 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    slli a1, a1, LGNATIVE
    add a1, a1, s_rfp
    sn a0, (a1)
    next

    .macro alu2 label, insn
\label:
    addi s_dsp, s_dsp, - NATIVE
    ln a0, (-1 * NATIVE)(s_dsp)
    ln a1, (0 * NATIVE)(s_dsp)
    \insn a0, a0, a1
    sn a0, (-1 * NATIVE)(s_dsp)
    next
    .endm

    alu2 .Lf_add, add
    alu2 .Lf_sub, sub
    alu2 .Lf_mul, mul
    alu2 .Lf_div, divu
    alu2 .Lf_shl, sll
    alu2 .Lf_shr, srl
    alu2 .Lf_and, and
    alu2 .Lf_or, or
    alu2 .Lf_xor, xor

    .macro alu1 label, insn
\label:
    ln a0, (-1 * NATIVE)(s_dsp)
    \insn a0, a0
    sn a0, (-1 * NATIVE)(s_dsp)
    next
    .endm

    alu1 .Lf_neg, neg
    alu1 .Lf_not, not
    alu1 .Lf_eqz, seqz
    alu1 .Lf_ltz, sltz

.Lf_select:
    addi s_dsp, s_dsp, -2 * NATIVE
    ln a1, (0 * NATIVE)(s_dsp)
    ln a2, (1 * NATIVE)(s_dsp)
    ln a0, (-1 * NATIVE)(s_dsp)
    bnez a0, 1f
    mv a1, a2
1:
    sn a1, (-1 * NATIVE)(s_dsp)
    next

.Lf_aligned:
    ln a0, (-1 * NATIVE)(s_dsp)
    addi a0, a0, NATIVE - 1
    andi a0, a0, ~ (NATIVE - 1)
    sn a0, (-1 * NATIVE)(s_dsp)
    next

.Lf_rawmove:
    addi s_dsp, s_dsp, -3 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    ln a2, (2 * NATIVE)(s_dsp)
    call memcpy
    next

.Lf_load:
    ln a0, (-1 * NATIVE)(s_dsp)
    ln a0, (a0)
    sn a0, (-1 * NATIVE)(s_dsp)
    next

.Lf_store:
    addi s_dsp, s_dsp, - 2 * NATIVE
    ln a0, (0 * NATIVE)(s_dsp)
    ln a1, (1 * NATIVE)(s_dsp)
    sn a0, (a1)
    next

    .section .rodata

    .macro defword name, strname, code, link=1000b
    .set .Llink_\@, \link

    .pushsection .rodata.str1.1, "aMS", @progbits, 1
91:
    .string "\strname"
92:
    .popsection

    .balign NATIVE
1000:
\name:
    nbyte \code         // Code pointer
    nbyte .Llink_\@     // Link to previous word
    nbyte 91b           // Name
    nbyte 92b - 91b - 1 // Length without NUL-terminator
    .endm

    defword _f_litlist, "_litlist", .Lf_litlist, -1
    defword _f_litstring, "_litstring", .Lf_litstring
    defword _f_jump, "_jump", .Lf_jump
    defword _f_jif, "_jif", .Lf_jif

    defword _f_return, "_return", .Lf_return
    defword _f_nop, "_nop", .Lf_nop
    defword _f_lit, "_lit", .Lf_lit
    defword _f_dot, ".", .Lf_dot
    defword _f_sdot, "s.", .Lf_sdot
    defword _f_rawexecute, "rawexecute", .Lf_rawexecute
    defword _f_ok, "_ok", .Lf_ok

    defword _f_dup, "dup", .Lf_dup      // ( a -- a a )
    defword _f_drop, "drop", .Lf_drop   // ( a -- )
    defword _f_swap, "swap", .Lf_swap   // ( a b -- b a )
    defword _f_over, "over", .Lf_over   // ( a b -- a b a )
    defword _f_rot, "rot", .Lf_rot      // ( a b c -- b c a )

    defword _f_dswap, "dswap", .Lf_dswap // ( a b c d -- c d a b )

    defword _f_add, "+", .Lf_add
    defword _f_sub, "-", .Lf_sub
    defword _f_mul, "*", .Lf_mul
    defword _f_div, "/", .Lf_div
    defword _f_and, "&", .Lf_and
    defword _f_or, "|", .Lf_or
    defword _f_xor, "^", .Lf_xor
    defword _f_shl, "<<", .Lf_shl
    defword _f_shr, ">>", .Lf_shr

    defword _f_neg, "neg", .Lf_neg
    defword _f_not, "not", .Lf_not

    defword _f_eqz, "=0", .Lf_eqz
    defword _f_ltz, "<0", .Lf_ltz
    defword _f_select, "?", .Lf_select

    defword _f_aligned, "aligned", .Lf_aligned
    defword _f_rawmove, "rawmove", .Lf_rawmove

    defword _f_lhere, "lhere", .Lf_lhere
    defword _f_lallot, "lallot", .Lf_lallot
    defword _f_nlallot, "nlallot", .Lf_nlallot
    defword _f_load_l, "@l", .Lf_load_l
    defword _f_store_l, "!l", .Lf_store_l

    defword _f_load, "@", .Lf_load
    defword _f_store, "!", .Lf_store

    defword _f_native, "native", lf_constant
        nbyte NATIVE

    defword _f_lgnative, "lgnative", lf_constant
        nbyte LGNATIVE

    defword _f_of_last, "=last", lf_constant
        nbyte last_word

    defword _f_of_here, "=here", lf_constant
        nbyte allot_pointer

    defword _f_of_definition, "=_definition", lf_constant
        nbyte lf_definition

    defword _f_of_constant, "=_constant", lf_constant
        nbyte lf_constant

    defword _f_of_noop, "=noop", lf_constant
        nbyte 1f
1:
        nbyte NATIVE, _f_return

    defword _f_nrot, "-rot", lf_definition
        // ( a b c -- c a b )
        nbyte _f_rot
        nbyte _f_rot
        nbyte _f_return

    defword _f_nip, "nip", lf_definition
        // ( a b -- b )
        nbyte _f_swap
        nbyte _f_drop
        nbyte _f_return

    defword _f_tuck, "tuck", lf_definition
        // ( a b -- b a b )
        nbyte _f_swap, _f_over
        nbyte _f_return

    defword _f_ddup, "ddup", lf_definition
        // ( a b -- a b a b )
        nbyte _f_over, _f_over
        nbyte _f_return

    defword _f_ddrop, "ddrop", lf_definition
        // ( a b -- )
        nbyte _f_drop, _f_drop
        nbyte _f_return

    defword _f_add_store, "+!", lf_definition
        // ( n p -- )
        nbyte _f_dup, _f_load, _f_rot
        // ( p orig n -- )
        nbyte _f_add, _f_swap, _f_store
        nbyte _f_return

    defword _f_here, "here", lf_definition
        nbyte _f_of_here, _f_load
        nbyte _f_return

    defword _f_last, "last", lf_definition
        nbyte _f_of_last,  _f_load
        nbyte _f_return

    defword _f_allot, "allot", lf_definition
        // ( n -- )
        nbyte _f_of_here, _f_add_store
        nbyte _f_return

    defword _f_align, "align", lf_definition
        nbyte _f_of_here, _f_load, _f_aligned
        nbyte _f_of_here, _f_store
        nbyte _f_return

    defword _f_commit, "commit", lf_definition
        // ( p n -- )
        nbyte _f_tuck
        // ( n p n )
        nbyte _f_here, _f_nrot, _f_rawmove
        // ( n )
        nbyte _f_allot
        nbyte _f_return

    defword _f_comma, ",", lf_definition
        // ( n -- ) Append native to data space
        nbyte _f_here, _f_native, _f_allot, _f_store
        nbyte _f_return

    defword _f_n_add, "n+", lf_definition
        // ( n1 n2 -- {n1 * NATIVE + n2} )
        nbyte _f_swap, _f_native, _f_mul, _f_add
        nbyte _f_return

    defword _f_execute, "execute", lf_definition
        nbyte _f_native, _f_add
        nbyte _f_rawexecute
        nbyte _f_return

    defword _f_rawdef, "rawdef", lf_definition
        // ( p:name n:name p:code -- )
        nbyte _f_nrot
        // ( p:code p:name n:name )
        nbyte _f_here, _f_over
        // ( p:code p:name n:name p:name' n:name )
        nbyte _f_dswap
        // ( p:code p:name' n:name p:name n:name )
        nbyte _f_commit
        // ( p:code p:name n:name )
        nbyte _f_swap, _f_rot
        // ( n:name p:name p:code )

        nbyte _f_align, _f_comma
        nbyte _f_last, _f_comma
        nbyte _f_comma
        nbyte _f_comma

        nbyte _f_lit, -4, _f_here, _f_n_add
        nbyte _f_of_last
        // ( p:word p:last )
        nbyte _f_store

        nbyte _f_return

    defword _f_rawlist, "rawlist", lf_definition
        // ( p:list -- p:payload n:payload )
        nbyte _f_dup, _f_native, _f_add
        // ( p:list p:payload )
        nbyte _f_swap, _f_load
        nbyte _f_return

    defword _f_define, "define", lf_definition
        // ( p:name n:name p:list -- )
        nbyte _f_nrot
        // ( p:list p:name n:name )
        nbyte _f_of_definition, _f_rawdef
        // ( p:list )
        nbyte _f_rawlist, _f_commit
        nbyte _f_return

    defword _f_var, "var", lf_definition
        // ( p:name n:name -- )
        nbyte _f_of_constant, _f_rawdef
        // ()
        nbyte _f_native, _f_here, _f_add
        // ( p ) Points to data space pointer after definition
        nbyte _f_comma
        nbyte _f_return

    defword _f_ifelse, "ifelse", lf_definition
        // ( n p:if p:else -- )
        nbyte _f_select
        nbyte _f_execute
        nbyte _f_return

    defword _f_if, "if", lf_definition
        // ( n p:if -- )
        nbyte _f_of_noop, _f_ifelse
        nbyte _f_return

    defword _f_while, "while", lf_definition
        // ( p:body p:cond -- )
        nbyte _f_lit, 2, _f_nlallot
        nbyte _f_lit, 1, _f_store_l // p:cond
        nbyte _f_lit, 0, _f_store_l // p:body
1:
        nbyte _f_lit, 1, _f_load_l, _f_execute
        nbyte _f_eqz, _f_jif, 2f
        nbyte _f_lit, 0, _f_load_l, _f_execute
        nbyte _f_jump, 1b
2:
        nbyte _f_return

    defword _f_repeat, "repeat", lf_definition
        nbyte _f_lit, 1, _f_nlallot
        nbyte _f_lit, 0, _f_store_l
1:
        nbyte _f_lit, 0, _f_load_l, _f_execute
        nbyte _f_jif, 1b

        nbyte _f_return

    defword _f_count, "count", lf_definition
        // ( n p -- )
        nbyte _f_lit, 3, _f_nlallot
        nbyte _f_lit, 2, _f_store_l
        nbyte _f_lit, 1, _f_store_l
        nbyte _f_lit, 0, _f_lit, 0, _f_store_l
1:
        nbyte _f_lit, 0, _f_load_l
        nbyte _f_lit, 1, _f_load_l
        nbyte _f_over, _f_sub, _f_eqz
        nbyte _f_jif, 2f

        nbyte _f_lit, 2, _f_load_l, _f_execute

        nbyte _f_lit, 0, _f_load_l
        nbyte _f_lit, 1, _f_add
        nbyte _f_lit, 0, _f_store_l
        nbyte _f_jump, 1b
2:
        nbyte _f_drop, _f_return

    .set _last_word, 1000b

    // Global variables
    .section .sdata, "aw", @progbits
    .balign NATIVE
last_word:
    .zero NATIVE
allot_pointer:
    .zero NATIVE

    .section .bss
    .balign NATIVE
line_buf:
    .zero 1024
token_buf:
    .zero 1024
data_stack:
    .zero 4096
return_stack:
    .zero 4096
allot_space:
    .zero 4096 * 16

    .section .note.GNU-stack, "", @progbits
