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

asflags-y += -nostdinc -I src -march=rv$(XLEN)i$(RVC_LETTER) -mabi=$(ABI)
ldflags-y += -nostdlib --no-dynamic-linker -m elf$(XLEN)lriscv

ldflags-$(PIE) += -pie
ldflags-$(FLAT_BINARY) += -T src/link.lds

ifeq ($(FLAT_BINARY),y)
  ifneq ($(START_ADDR),)
    ldflags-y += -Ttext=$(START_ADDR)
    asflags-y += -DSTART_ADDR=$(START_ADDR)
  endif
endif

asflags-y += $(ASFLAGS)
ldflags-y += $(LDFLAGS)

program = fiveth
objs-y += fiveth_linux.o fiveth.o
objs-$(PIE) += relocate.o

targets-y += $(outdir)/$(program)
targets-$(FLAT_BINARY) += $(outdir)/$(program).bin

.PHONY: all
all: $(targets-y)
	@echo ""
	@echo "* Build complete: $^"

$(outdir):
	mkdir -p $@

$(outdir)/%.o: src/%.S | $(outdir)
	$(AS) $(asflags-y) -MMD -c -o $@ $<

$(outdir)/$(program): $(addprefix $(outdir)/,$(objs-y)) | src/link.lds $(outdir)
	$(LD) $(ldflags-y) -o $@ $^

%.bin: %
	$(OBJCOPY) -O binary $< $@

$(outdir)/fiveth.o: src/bootstrap.five

.PHONY: clean
clean:
	rm -rf $(outdir)/

.PHONY: qemu
qemu:
	qemu-riscv$(XLEN) $(outdir)/$(program)

-include $(wildcard $(outdir)/*.d)
