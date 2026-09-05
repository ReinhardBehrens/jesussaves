; SPDX-License-Identifier: GPL-3.0-only
bits 64
default rel
extern background_data
extern pixels
extern scene
; 4K framebuffer compositing. SSE2 bilinear resampling in two separable passes.
; The cloud image is resampled once. Fire is composited additively each frame.
;
section .rodata
align 16
weight256: dw 256,256,256,256,256,256,256,256
BG_W equ 3840
BG_H equ 2160
section .bss
align 64
background4k: resb 3840*2160*4
scratch: resb 3840*2160*4
xindices: resb 3840*4
xweights: resb 3840*4
ready: resb 4
sw: resb 4
sh: resb 4
destheight: resb 4
source: resb 8
dest: resb 8
section .text
global compose_backdrop
compose_backdrop:
    sub rsp,8
    cmp dword [rel ready],0
    jne .Lbackground_ready
    lea rdi,[rel background_data]
    mov esi,BG_W
    mov edx,BG_H
    lea rcx,[rel background4k]
    mov r8d,2160
    call scale_image
    mov dword [rel ready],1
.Lbackground_ready:
    lea rdi,[rel scene]
    lea rsi,[rel background4k]
    mov ecx,3840*2160/2
    rep movsq
    lea rdi,[rel pixels]
    mov esi,512
    mov edx,160
    lea rcx,[rel scene+3840*1200*4]
    mov r8d,960
    call scale_image
    add rsp,8
    ret

; src rdi, width esi, height edx; dest rcx, dest height r8d. Width always 3840.
; Adds interpolated channels with saturation. Destination must be initialized.
;
scale_image:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov qword [rel source],rdi
    mov qword [rel dest],rcx
    mov dword [rel sw],esi
    mov dword [rel sh],edx
    mov dword [rel destheight],r8d
    lea r12,[rel xindices]
    lea r13,[rel xweights]
    mov r9d,esi
    dec r9d
    shl r9d,8
    xor ebx,ebx
.Lxmap:
    mov eax,ebx
    imul eax,r9d
    xor edx,edx
    mov ecx,3839
    div ecx
    mov edx,eax
    shr eax,8
    and edx,255
    cmp ebx,3839
    jne .Lstoremap
    dec eax
    mov edx,256
.Lstoremap:
    mov dword [r12+rbx*4],eax
    mov dword [r13+rbx*4],edx
    inc ebx
    cmp ebx,3840
    jb .Lxmap
    lea r14,[rel scratch]
    mov r15,qword [rel source]
    xor r11d,r11d
    pxor xmm7,xmm7
.Lhrow:
    xor ebx,ebx
.Lhcol:
    mov eax,dword [r12+rbx*4]
    movd xmm0,dword [r15+rax*4]
    movd xmm1,dword [r15+rax*4+4]
    punpcklbw xmm0,xmm7
    punpcklbw xmm1,xmm7
    movd xmm2,dword [r13+rbx*4]
    pshuflw xmm2,xmm2,0
    pshufd xmm2,xmm2,0
    movdqa xmm3,oword [rel weight256]
    psubw xmm3,xmm2
    pmullw xmm0,xmm3
    pmullw xmm1,xmm2
    paddw xmm0,xmm1
    psrlw xmm0,8
    packuswb xmm0,xmm7
    movd dword [r14+rbx*4],xmm0
    inc ebx
    cmp ebx,3840
    jb .Lhcol
    add r14,3840*4
    mov eax,dword [rel sw]
    lea r15,[r15+rax*4]
    inc r11d
    cmp r11d,dword [rel sh]
    jb .Lhrow
    mov r15,qword [rel dest]
    xor r11d,r11d
.Lvrow:
    mov eax,dword [rel sh]
    dec eax
    shl eax,8
    imul eax,r11d
    xor edx,edx
    mov ecx,dword [rel destheight]
    dec ecx
    div ecx
    mov edx,eax
    shr eax,8
    and edx,255
    cmp r11d,ecx
    jne .Lymapready
    dec eax
    mov edx,256
.Lymapready:
    imul eax,3840*4
    lea r14,[rel scratch]
    add r14,rax
    movd xmm5,edx
    pshuflw xmm5,xmm5,0
    pshufd xmm5,xmm5,0
    movdqa xmm6,oword [rel weight256]
    psubw xmm6,xmm5
    xor ebx,ebx
align 16
.Lvcol:
    movdqa xmm0,oword [r14+rbx]
    movdqa xmm1,oword [r14+rbx+3840*4]
    movdqa xmm2,xmm0
    movdqa xmm3,xmm1
    punpcklbw xmm0,xmm7
    punpcklbw xmm1,xmm7
    punpckhbw xmm2,xmm7
    punpckhbw xmm3,xmm7
    pmullw xmm0,xmm6
    pmullw xmm1,xmm5
    pmullw xmm2,xmm6
    pmullw xmm3,xmm5
    paddw xmm0,xmm1
    paddw xmm2,xmm3
    psrlw xmm0,8
    psrlw xmm2,8
    packuswb xmm0,xmm2
    paddusb xmm0,oword [r15+rbx]
    movdqa oword [r15+rbx],xmm0
    add ebx,16
    cmp ebx,3840*4
    jb .Lvcol
    add r15,3840*4
    inc r11d
    cmp r11d,dword [rel destheight]
    jb .Lvrow
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
