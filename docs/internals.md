# Fiveth internals

## Integer types

The basic integer data types are named as RISC-V does it:

- `b`: byte, 8 bits
- `h`: half-word, 16 bits
- `w`: word, 32 bits
- `d`: double-word, 64 bits

(`d` isn't used anywhere yet as of writing, but it's part of the series)

Additionally, just so that Fiveth is portable between `rv32` and `rv64`:

- `n`: native, `XLEN` bits (i.e. `32` on `rv32`, `64` on `rv64`)

For convenience "native" will be used as a noun.

In assembly code, `NATIVE` is the number of bytes in a native, `LGNATIVE` is
log-base-`2` of `NATIVE`. `ln`/`sn` are aliased to `lw`/`sw` on `rv32` and
`ld`/`sd` on `rv64`. `nbyte` is aliased to `.4byte` on `rv32` and `.8byte` on
`rv64`.

In Fiveth, the word `native` gives the number of bytes in a native, and
`lgnative` gives the log-base-`2` of that.

`@` and `!` are loads and stores for natives. The words `{b,h,w}@{,u}` and
`{b,h,w}!` can be used to load/store the other integer data types.

For loads, the `u`-suffixed words means to load and zero-extend, while non-`u`
means to sign extend. For stores, only the low bits are stored. These work just
like the corresponding instructions.

On `rv32`, even though the `lwu` instruction does not exist, `w@u` is still
defined and is equivalent to `w@`.

## Strings and lists

Strings are `start` and `len`. They're usually represented as two elements on
the stack `p:str n:str`.

Lists are like quotations in Factor: `[ + ]`. Lists implicitly end with a
`return`. So the list `[ + ]` as represented by `l:list` is a pointer to two
word pointers, `+, return`.

## Dictionary

The dictionary is organized in a linked list:

```c
struct word {
    void *code;
    struct word *link; // -1 if last word
    const char *name;
    size_t name_len;
};

struct word *last_word; // Get address with `=last`
```

## Data stack

Each element on a data stack is a native. These are "cells" in Forth.

The data stack grows upward and the register name for it is aliased to `s_dsp`.

## Return stack

The return stack, unlike in Forth, is organized in a stack frame structure.

The return stack grows upward as well, and two registers, aliases `s_rsp` and
`s_rfp`, are used for it. Each stack frame looks like this:

```
s_rsp   ----------------
               ...
        ----------------
         Local 1
        ----------------
         Local 0
s_rfp   ----------------
         Return address
        ----------------
         Previous s_rfp
        ----------------
```

This design makes it easier to use variables on the return stack.

`l,` pops top of data stack and appends it to the locals. `n l@` loads the
`n`-th local. `n l!` stores to the `n`-th local. For more complex use cases
`lhere` and `lallot` is available. You can create local byte buffers with these.

Beware that since each list has its own stack frame, locals *do not work* in
control structures. It's also difficult to define new words that work on locals.

## Allot space and committed literals

The allot space is simply maintained as a pointer to the top of the allocated
area. `here` gives you the current pointer, and `n allot` bumps the pointer by
`n` bytes.

For advanced usage, you can manipulate the pointer directly by loading or
storing to `=here`. Note that unlike in Forth, parsing uses the allot space, so
generally should be done in .
