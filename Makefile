MAKEFLAGS += -rR

include config.mk

.EXTRA_PREREQS += Makefile config.mk

ifeq ($(XLEN),64)
  ABI = lp64
else ifeq ($(XLEN),32)
  ABI = ilp32
else
  $(error XLEN needs to be 32 or 64)
endif

ifeq ($(RVC),y)
  RVC_LETTER = c
else
  RVC_LETTER =
endif

ASFLAGS += -nostdinc -I src -march=rv$(XLEN)i$(RVC_LETTER) -mabi=$(ABI)
LDFLAGS += -nostdlib --no-dynamic-linker -no-pie -m elf$(XLEN)lriscv

program = fiveth
objs = fiveth_linux.o fiveth.o

.PHONY: all
all: $(outdir)/$(program)
	@echo ""
	@echo "* Build complete: $^"

$(outdir):
	mkdir -p $@

$(outdir)/%.o: src/%.S | $(outdir)
	$(AS) $(ASFLAGS) -MMD -c -o $@ $<

$(outdir)/$(program): $(addprefix $(outdir)/,$(objs)) | $(outdir)
	$(LD) $(LDFLAGS) -o $@ $^

$(outdir)/fiveth.o: src/bootstrap.five

.PHONY: clean
clean:
	rm -rf $(outdir)/

.PHONY: qemu
qemu:
	qemu-riscv$(XLEN) $(outdir)/$(program)

-include $(wildcard $(outdir)/*.d)
