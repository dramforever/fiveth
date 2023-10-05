# Basic primitives

## Unary and binary operators

The binary operators are like what they mean in C:

- `+` and `-` (`*` and `/` are omitted)
- `<<`, `>>` (signed/arithmetic), `>>u` (unsigned/logical)
- `&`, `|`, `^`
- `<`, `>`, `<=`, `>=`, `=` (not `==`)

The unary operator names are mostly self-explanatory:

- `neg`, `not`
- `<0`, `>0`, `<=0`, `>=0`, `=0`

`not` is bitwise-not. For logical not, use `=0`.

## Stack manipulation words

These corresponds to stack manipulation words in Forth.

```
dup ; ( a -- a a )
nip ; ( a b -- b )
swap ; ( a b -- b a )
rot ; ( a b c -- b c a )
nrot ; ( a b c -- c a b ) instead of -rot
drop ; ( a -- )
over ; ( a b -- a b a )
tuck ; ( a b -- b a b )
```

The prefix is `p` (for "pair") instead of `2` for these operations:

```
pdup ; ( a b -- a b a b )
pdrop ; ( a b -- )
prot ; ( a b c d e f -- c d e f a b )
pnrot ; ( a b c d e f -- e f a b c d )
pswap ; ( a b c d -- c d a b )
```

## `native` and related things

`native` is the number of bytes in a native. For use in shifting operations to
avoid multiplication, `lgnative` is the log-base-2 of that.

For convenience, `+n` is `( a b -- a+b*native )`.

`aligned` aligns a number to the next multiple of `native`.
