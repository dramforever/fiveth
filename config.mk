### Build config

# Output directory
outdir = build

### Target information

# Platform?
PLATFORM = linux

# App script to run at startup
APP = shell

# 64-bit or 32-bit system?
XLEN = 64

# Processor supports compressed instructions?
RVC = y

# Build flat binary?
FLAT_BINARY = n

# Generate position-independent executable?
PIE = n
# Note: Indirect threaded code has a *lot* of relocations. If PIE=y, consider
# using LLD and turning on either -z pack-relative-relocs (LLD >= 15) or
# --pack-dyn-relocs=relr to save on space.

# Start Address of flat binary
START_ADDR =
# (Depends on FLAT_BINARY=y)

### Build details

# Platform-specific initialization code
INIT_OBJ = init_$(PLATFORM).o

# Scripts to run at boot
SCRIPTS = bootstrap.five drivers_$(PLATFORM).five utils.five $(APP).five

### Toolchain

# Tools to use when building
# - The "assembler" needs to be a C compiler, as we do use the C preprocessor.
# - The linker needs to support creating RISC-V binaries.
# - If FLAT_BINARY=y, objcopy to convert ELF to flat binary
AS = clang --target=riscv$(XLEN)-unknown-linux-gnu
LD = ld.lld
OBJCOPY = llvm-objcopy

# Note: LLD < 15 does not support object files created -mrelax. If using an old
# LLD, add -mno-relax to ASFLAGS below.

# GNU toolchain from Nixpkgs
# AS = riscv$(XLEN)-unknown-linux-gnu-gcc
# LD = riscv$(XLEN)-unknown-linux-gnu-ld
# OBJCOPY = riscv$(XLEN)-unknown-linux-gnu-objcopy

# GNU toolchain from Ubuntu
# AS = riscv$(XLEN)-linux-gnu-gcc
# LD = riscv$(XLEN)-linux-gnu-ld
# OBJCOPY = riscv$(XLEN)-linux-gnu-objcopy

### Options

# Flags to pass to "assembler"
# ASFLAGS += -mno-relax

# Flags to pass to linker
# LDFLAGS += --pack-dyn-relocs=relr
# LDFLAGS += -z pack-relative-relocs
