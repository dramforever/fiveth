# Fiveth

A stack-based language implemented in RISC-V assembly.

## Building and running Fiveth

- Edit `config.mk` to suit your environment
- `make` to build the program

With the default config this should end a message like:

```
* Build complete: build/fiveth
```

The default configuration is to run an interactive Fiveth shell that works under
a 64-bit RISC-V Linux environment. You can now:

- `make qemu` to run it in QEMU user-mode emulation
- `make run` to run it directly, if you are actually on RISC-V

Try typing some simple Fiveth programs. Outputs are shown after a semicolon.

```
0 > 1 2 + .  ; 3
0 > 10 [ . ] count  ; 0 1 2 3 4 5 6 7 8 9
0 > "Hello, world!" s.  ; Hello, world!
```

Press Ctrl-D to quit. [`docs/shell.md`](docs/shell.md) has more details on
running and using the Fiveth interactive shell.

## Installing the required tools

On Ubuntu 22.04:

```console
# apt install qemu-user make
# # If using GNU toolchain
# apt install gcc-riscv64-linux-gnu
# # If using LLVM toolchain
# apt install clang lld
```

If you have Nix, you can try to use the provided `shell.nix` or `flake.nix`.

On other systems, you can try to acquire a LLVM toolchain or a RISC-V toolchain,
as well as GNU make. To run the Fiveth in an emulator, `qemu-riscv64` can be
used to emulate a Linux binary but is only supported on Linux hosts.
