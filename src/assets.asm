; SPDX-License-Identifier: GPL-3.0-only
bits 64
default rel

; Embedded immutable assets and a 4K readback framebuffer.
section .rodata
align 16
global field
field: incbin "assets/text-sdf.bin"
align 16
global background_data
background_data: incbin "build/background.bgra"
section .bss
align 64
global scene
scene: resb 3840*2160*4
section .note.GNU-stack noalloc noexec nowrite progbits
