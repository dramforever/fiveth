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

isa := rv$(XLEN)i

ifeq ($(RVC),y)
  isa := $(isa)c
endif

# Assembler requires specifying Zicsr and Zifencei?
AS_SPLIT_ZI = $(shell $(AS) -march=rv$(XLEN)g_zicsr_zifencei -c -o /dev/null -x c /dev/null >/dev/null 2>&1 && echo y || echo n)

ifeq ($(AS_SPLIT_ZI),y)
  isa := $(isa)_zicsr_zifencei
endif

asflags-y += -nostdinc -I src -I $(outdir)
asflags-y += -march=$(isa) -mabi=$(ABI)
ldflags-y += -nostdlib --no-dynamic-linker -m elf$(XLEN)lriscv

ldflags-$(PIE) += -pie
lds-$(FLAT_BINARY) += src/link.lds

ifeq ($(FLAT_BINARY),y)
  ifneq ($(START_ADDR),)
    ldflags-y += -Ttext=$(START_ADDR)
    asflags-y += -DSTART_ADDR=$(START_ADDR)
  endif
endif

asflags-y += $(ASFLAGS)
ldflags-y += $(LDFLAGS)

# This must be the last ldflags
ldflags-$(FLAT_BINARY) += -T

program = fiveth
objs-y += $(INIT_OBJ) fiveth.o script.o
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
	$(AS) -MMD -c -o $@ $(asflags-y) $<

$(outdir)/$(program): $(lds-y) $(addprefix $(outdir)/,$(objs-y)) | $(outdir)
	$(LD) -o $@ $(ldflags-y) $^

%.bin: %
	$(OBJCOPY) -O binary $< $@

$(outdir)/script.o: $(outdir)/_full_script.five

$(outdir)/_full_script.five: $(addprefix src/,$(SCRIPTS))
	cat $^ > $@

.PHONY: clean
clean:
	rm -rf $(outdir)/

.PHONY: qemu
qemu:
	@-stty raw -echo
	@-qemu-riscv$(XLEN) $(outdir)/$(program)
	@-stty sane

.PHONY: run
run:
	@-stty raw -echo
	@-$(outdir)/$(program)
	@-stty sane

-include $(wildcard $(outdir)/*.d)
