# Stack effects

Stack effects are written as in Forth, in a comment.

```
"my-new-word" [ ; ( {before} -- {after} )
    ...
] define
```

Elements are written top-of-stack-last. For example, the stack effect of `tuck`
can be written:

```
( a b -- b a b )
```

Within code, a similar notation without `--` is used to remind the reader of
what's currently on the stack.

```
; ( a b )
swap ; ( b a )
```

Some letters have conventional meanings:

- `p`: Address-of (`p` for "pointer")
- `n`: Length in bytes
- `l`: List (Address of count)

The stack effect of a list may also be annotated using `l:( )`. For example, the
stack effect of `run` can be written:

```
( ..a l:( ..a -- ..b ) -- ..b )
```

Do note that these annotations are just comments. Fiveth does not do any stack
effect checking, so it's often the annotations get lazy about stack effects of
control structures.
