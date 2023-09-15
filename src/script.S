    .section .rodata
    .global _script
    .global _script_end
    .type _script, @object
_script:
    .incbin "_full_script.five"
    .size _script, . - _script
_script_end:

    .section .note.GNU-stack, "", @progbits
