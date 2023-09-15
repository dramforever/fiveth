PHDRS {
    text PT_LOAD;
    data PT_LOAD;
    dynamic PT_DYNAMIC;
}

SECTIONS {
    __executable_start = .;

    .text : {
        *(.text.entry)
        *(.text .text.*)
    } :text

    .rodata : { *(.rodata .rodata.*) }
    .rela.dyn : { *(.rela*) }
    .relr.dyn : { *(.relr*) }

    .dynamic : { *(.dynamic) } :data :dynamic

    .got : { *(.got) } :data
    .data : { *(.data .data.*) }

    __global_pointer$ = .;

    .sbss : { *(.sbss .sbss.*) }
    .bss : { *(.bss .bss.*) }

    /DISCARD/ : {
        *(.dynsym .dynstr .hash .gnu.hash)
    }
}
