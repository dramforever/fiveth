# The Fiveth interactive shell

## Notes for running under Linux

The shell assumes that it's running in something like a serial terminal and has
access to a terminal in "raw mode".

`make qemu` and `make run` sets this up for you. It mostly just boils down to:

```
stty raw -echo
build/fiveth
stty sane
```

Since the shell takes control of the terminal, if it gets stuck you might have
to kill it from another shell session. Sorry.

## The prompt

The shell starts with a prompt like this

```
0 >
```

The number is simply the current number of natives in the data stack, or stack
depth. If you open a list without closing it, the `>` changes to a `|`
indicating line continuation:

```
0 > "hello" [
0 |   "Hello, world!" s.
0 | ] define  ;
0 >
```

## Line editing

- `CR` (Return or Enter key): Commit current line
- `BS` or `DEL` (Backspace): Delete last character
- Ctrl-C: Cancels current input
- Ctrl-D: Exits the shell

Known issues:

- Other control characters are ignored. This means, for example, arrow keys,
  which are encoded as `\x1a [ <some-letter>`, generate weird input.
- Non-ASCII characters are currently not handled correctly if you start editing
  a line containing them. Sorry.

## The output comment

When the shell finishes processing a section of the input, either normally or
abnormally, it will write an output comment starting with `"  ; "` (two spaces,
a semicolon, one space).

- If a line has been cancelled, the comment is `"  ; ///"`, indicating that the
  line was not executed

  ```
  0 > I don't need this line anymore  ; ///
  0 >
  ```

- If a line has a parse error, the comment is `"  ; ???"`. Error messages comes
  in the next few lines.

  ```
  0 > 10 [ nonexistent ] count  ; ???
  ! Undefined word
  ! 10 [ >>>nonexistent<<< ] count
  0 >
  ```

- If a line is executed, the comment is `"  ; "`, then output of the code

  ```
  0 > 1 2 + .  ; 3
  0 > "test" s.  ; test
  0 >
  ```
