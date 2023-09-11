# Gotchas

Fiveth is a low-level language. It won't protect you from messing up. Mostly
simply because the author is too lazy to add the necessary checks.

Maybe in the future additional checks will help make some of these problems
report errors instead of crashing or silently corrupting data.

## Memory access

Fiveth provides you with raw memory access. If you do it wrong, crashing is the
best you can hope for.

## Overflowing and underflowing buffers

There's currently no checks for overflowing or underflowing stacks, or bound
checks for buffers used for parsing.

## Literal lifetimes

Fiveth code is parsed one line at a time. If at the end of any line, no more
literal lists remain open, anything already parsed is evaluated. The buffer for
parsed results is then reused for the following lines.

This means literal lists and strings are only valid until a line is "done".

```
; Okay
"hello" [ "Hello, world!" s. nl ] define

; Okay
"hello" [
    "Hello, world!" s. nl
] define

; Wrong!
"hello" [
    "Hello, world!" s. nl
]
define  ; Parsing this line overwrites the literal string and list

; Wrong!
"hello"
[   ; Parsing this line overwrites the literal string
    "Hello, world!" s. nl
] define
```

The easiest way to ensure this doesn't cause problems is to commit all literals
that you'd want to use later, within the same line continuation.

Specifically when defining a new word, putting `[` on the same line as the name,
and `define` on the same line after `]` means that the name and body are valid
as `define` executes. `define` commits the word name and body for you, so
anything you do in the body of a `define`-ed word won't have this problem.
