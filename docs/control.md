# Basic control structures

This is an overview of the control structures

## Truthiness

Throughout, the C convention of truthiness is used: "true" is anything non-zero,
and "false" is zero.

## Data stack usage

Control structures in Fiveth do not use the data stack for bookkeeping. While a
list passed to a control structure is running, anything below the "arguments"
passed to it on the stack remains accessible.

Moreover, the list is not required to maintain the value of anything below the
"arguments", or even maintain depth of the stack, as long as the expected
"return values" are given.

This concept of "the rest of the stack" is represented in stack effects listed
below as `..`.

## `repeat`

`repeat ; ( .. l:( .. -- .. c ) -- .. )` runs `l`, and pops `c`. If `c` is true, repeat the process, otherwise stop.

`l` is run at least once.

```
[ is_done =0 ] repeat ; Wait until done
```

## `while`

`while ; ( .. cond:( .. -- .. c ) body:( .. -- .. ) -- .. )` runs `cond` and pops `c`. If `c` is true, run `body` and repeat. Otherwise stop.

## `ifelse` and `if`

`ifelse ; ( .. c then:( .. -- .. ) else:( .. -- .. ) -- .. )` runs `then` if `c` is true, and runs `else` if `c` is false.

`if ; ( .. c then:( .. -- .. ) .. )` is equivalent to `[ ] ifelse`.

```
; Print odd numbers up to 100

100 [
    dup 1 & [ . ] [ drop ] ifelse
] count
```

## `begin_case`, `end_case`, `case`

Usage:

```
begin_case
[ cond1 ] [ body1 ] case
[ cond2 ] [ body2 ] case
; ...
end_case
```

Equivalent to an `ifelse` chain:

```
[ cond1 ] [ body1 ] [
    [ cond2 ] [ body2 ] [
        ...
    ] ifelse
] ifelse
```

### Implementation details

`begin_case ; ( -- t )` pushes a temporary tracking value on the data stack. The temporary tracking value is `1` if a case has been run, and `0` otherwise.

`case` has the following three possibilities:

```
( ..a 0 cond:( ..a -- ..a c ) body:( ..a -- ..b ) -- ..a 0 ) if c == 0
Run cond, if c is false, run body and push 0

( ..a 0 cond:( ..a -- ..a c ) body:( ..a -- ..b ) -- ..b 1 ) if c != 0
Run cond, if c is true, run body and push 1

( ..a 1 cond:( ..a -- ..a c ) body:( ..a -- ..b ) -- ..a 1 )
Don't run cond or body
```

`end_case ; ( t -- )` removes the temporary tracking value from the data stack
