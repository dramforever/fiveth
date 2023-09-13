### Build config

# Output directory
outdir = build

### Target information

# 64-bit or 32-bit system?
XLEN = 64
# XLEN = 32

# Processor supports compressed instructions?
RVC = y
# RVC = n

### Toolchain

# Tools to use when building
# - The "assembler" needs to be a C compiler, as we do use the C preprocessor.
# - The linker needs to support creating RISC-V binaries.
AS = clang --target=riscv$(XLEN)-unknown-linux-gnu
LD = ld.lld

# Note: LLD < 15 does not support object files created -mrelax. If using an old
# LLD, add -mno-relax to ASFLAGS below.

# GNU toolchain from Nixpkgs
# AS = riscv$(XLEN)-unknown-linux-gnu-gcc
# LD = riscv$(XLEN)-unknown-linux-gnu-ld

# GNU toolchain from Ubuntu
# AS = riscv$(XLEN)-linux-gnu-gcc
# LD = riscv$(XLEN)-linux-gnu-ld

### Options

# Flags to pass to "assembler"
# ASFLAGS += -mno-relax

# Flags to pass to linker
# LDFLAGS +=
