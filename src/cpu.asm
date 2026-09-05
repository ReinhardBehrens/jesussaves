; SPDX-License-Identifier: GPL-3.0-only
; Pure CPU/SSE2 backend. SDL only presents the already-rendered 4K framebuffer.
bits 64
default rel
extern heat, turbulence, tick, scene, background_data, animtime, clock_started
extern compose_scene
extern SDL_CreateRenderer, SDL_CreateTexture, SDL_UpdateTexture, SDL_RenderCopy
extern SDL_RenderPresent, SDL_DestroyTexture, SDL_DestroyRenderer
section .rodata
align 16
c_one: dd 1.0,1.0,1.0,1.0
c_detail: dd 1.05,1.05,1.05,1.05
c_base: dd 0.65,0.65,0.65,0.65
c_red: dd 3.1,3.1,3.1,3.1
c_green: dd 1.7,1.7,1.7,1.7
c_blue: dd 0.65,0.65,0.65,0.65
c_rgb: dd 255.0,255.0,255.0,255.0
c_alpha: dd 0xff000000,0xff000000,0xff000000,0xff000000
section .bss
align 64
global pixels
pixels: resb 512*160*4
cpu_renderer: resq 1
cpu_texture: resq 1
section .text
global cpu_init
cpu_init:
    sub rsp,8
    mov esi,-1
    mov edx,1 ; SDL_RENDERER_SOFTWARE: no GPU shading even on accelerated hardware
    call SDL_CreateRenderer wrt ..plt
    mov [cpu_renderer],rax
    test rax,rax
    jz .fail
    mov rdi,rax
    mov esi,0x16362004
    mov edx,1
    mov ecx,3840
    mov r8d,2160
    call SDL_CreateTexture wrt ..plt
    mov [cpu_texture],rax
    test rax,rax
    jz .fail
    xor eax,eax
    add rsp,8
    ret
.fail:
    mov eax,-1
    add rsp,8
    ret

; Both CPU scene components share the same scalar time input as the GPU hook.
global cpu_render
cpu_render:
    sub rsp,8
    movss [animtime],xmm0
    mov dword [clock_started],1
    test edi,edi
    jnz .background
    call cpu_flame_color
    call compose_scene
    xor eax,eax
    add rsp,8
    ret
.background:
    lea rdi,[scene]
    lea rsi,[background_data]
    mov ecx,3840*2160/2
    rep movsq
    xor eax,eax
    add rsp,8
    ret

global cpu_draw
cpu_draw:
    sub rsp,8
    call cpu_render
    mov rdi,[cpu_texture]
    xor esi,esi
    lea rdx,[scene]
    mov ecx,3840*4
    call SDL_UpdateTexture wrt ..plt
    test eax,eax
    js .done
    mov rdi,[cpu_renderer]
    mov rsi,[cpu_texture]
    xor edx,edx
    xor ecx,ecx
    call SDL_RenderCopy wrt ..plt
    test eax,eax
    js .done
    mov rdi,[cpu_renderer]
    call SDL_RenderPresent wrt ..plt
    xor eax,eax
.done:
    add rsp,8
    ret

global cpu_shutdown
cpu_shutdown:
    sub rsp,8
    mov rdi,[cpu_texture]
    test rdi,rdi
    jz .renderer
    call SDL_DestroyTexture wrt ..plt
.renderer:
    mov rdi,[cpu_renderer]
    test rdi,rdi
    jz .done
    call SDL_DestroyRenderer wrt ..plt
.done:
    add rsp,8
    ret

; SIMD temperature -> RGB emission with moving multiscale density modulation.
global cpu_flame_color
cpu_flame_color:
    lea r8,[heat+4]
    lea r9,[pixels]
    xor ecx,ecx
    pxor xmm6,xmm6
    movaps xmm4,[c_one]
    movaps xmm5,[c_rgb]
.row:
    mov eax,[tick]
    add eax,ecx
    and eax,255
    shl eax,11
    lea r10,[turbulence]
    add r10,rax
    xor eax,eax
.pixel:
    movups xmm0,[r8+rax]
    movaps xmm3,[r10+rax]
    mulps xmm3,[c_detail]
    addps xmm3,[c_base]
    maxps xmm3,xmm6
    mulps xmm0,xmm3
    movaps xmm1,xmm0
    movaps xmm2,xmm0
    mulps xmm0,[c_red]
    mulps xmm1,[c_green]
    minps xmm0,xmm4
    minps xmm1,xmm4
    minps xmm2,xmm4
    mulps xmm0,xmm0
    mulps xmm1,xmm1
    movaps xmm3,xmm2
    mulps xmm2,xmm2
    mulps xmm2,xmm3
    mulps xmm2,[c_blue]
    mulps xmm0,xmm5
    mulps xmm1,xmm5
    mulps xmm2,xmm5
    cvttps2dq xmm0,xmm0
    cvttps2dq xmm1,xmm1
    cvttps2dq xmm2,xmm2
    pslld xmm0,16
    pslld xmm1,8
    por xmm0,xmm1
    por xmm0,xmm2
    por xmm0,[c_alpha]
    movaps [r9+rax],xmm0
    add eax,16
    cmp eax,512*4
    jb .pixel
    add r8,514*4
    add r9,512*4
    inc ecx
    cmp ecx,160
    jb .row
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
