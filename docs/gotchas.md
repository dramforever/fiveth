# Gotchas

Fiveth is a low-level language. It won't protect you from messing up. Mostly
simply because the author is too lazy to add the necessary checks.

Maybe in the future additional checks will help make some of these problems
report errors instead of crashing or silently corrupting data.

## Memory access

Fiveth provides you with raw memory access. If you do it wrong, crashing is the
best you can hope for.

## Overflowing and underflowing

There's currently no checks for overflowing or underflowing stacks.

## Line-based parsing

To make handling of parsing errors easier, parsing is done line by line. The
parsed result is only run if an entire line has been parsed. This means that
defined words won't exist until the next line.

```
"print" [ . ] define  3 print ; Undefined word "print"
```
