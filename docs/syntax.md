# Basic syntax

This is a brief overview of the syntax. Basic familiarity with something like
Forth is assumed.

## Words and numbers

Words are separated by spaces. If a word starts with an ASCII digit, it will be
parsed as a number. Other words perform their defined actions.

```
1 2 + .
words
```

## Comments

The word `;` is special. It and everything after it in a line is ignored as a
comment:

```
0 ; Push 123 on the stack
words ; Show currently defined words
```

## String literals

The `"` is special. String literals are enclosed in `"`. It pushes the starting
address and (byte) length of the string:

```
"test" ; Pushes an address and 4
; The first 4 bytes at the address are ASCII 't' 'e' 's' 't'
```

## List literals

The words `[` and `]` are special. These are *list literals* and represent a
fragment of code. On the stack it is a single address of the start of the
fragment. `run` runs a list.

Lists can nest and can span multiple lines.

```
1 . ; Prints 1
1 [ . ] run ; Prints 1 with extra steps

10 [ . ] count ; Prints 0 through 9

10 [
    .
] count ; Same

10 [ [ . ] count nl ] count ; Prints a number triangle

```
