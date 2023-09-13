# Fiveth

A (work in progress) stack-based language implemented in RISC-V assembly.

## Building and running Fiveth

- Edit `config.mk` to suit your environment
- `make` to build the program
- `make qemu` to run QEMU user-mode emulation

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
