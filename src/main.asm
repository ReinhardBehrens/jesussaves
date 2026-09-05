; SPDX-License-Identifier: GPL-3.0-only
bits 64
default rel
extern SDL_CreateWindow
extern SDL_Delay
extern SDL_DestroyWindow
extern SDL_GetError
extern SDL_GetPerformanceCounter
extern SDL_GetTicks
extern SDL_Init
extern SDL_PollEvent
extern SDL_Quit
extern SDL_SetHint
extern SDL_ShowCursor
extern atoi
extern fclose
extern fopen
extern fprintf
extern fwrite
extern getenv
extern gpu_configure
extern gpu_draw
extern gpu_headless
extern gpu_init
extern gpu_readback
extern gpu_shutdown
extern perror
extern puts
extern SDL_EnableScreenSaver
extern cpu_init, cpu_draw, cpu_render, cpu_shutdown
extern SDL_CreateWindowFrom, SDL_GL_LoadLibrary, SDL_setenv, strtoull
extern stderr
extern scene
extern strcmp
extern strtof
; Ubuntu x86-64, NASM Intel syntax. No C/C++ rendering source.
; SSE2 is baseline on AMD64: four floating-point heat cells / RGB pixels.
; System V ABI. SDL2 owns only the window, texture upload and presentation.
;
W equ 512
H equ 160
STRIDE equ (W+2)*4
CELLS equ (H+2)*(W+2)
section .rodata
align 16
cooling: dd 0.008,0.008,0.008,0.008
align 16
blend: dd 0.09,0.09,0.09,0.09
flowgain: dd 2.7,2.7,2.7,2.7
flowbias: dd 3.0,3.0,3.0,3.0
coolgain: dd 0.005,0.005,0.005,0.005
fuelgain: dd 0.8,0.8,0.8,0.8
fuelbase: dd 0.52,0.52,0.52,0.52
half: dd 0.5,0.5,0.5,0.5
title: db `JESUS SAVES | Gold & Flame | Esc to exit`,0
cpuarg: db "--cpu",0
gpuarg: db "--gpu",0
saverarg: db "--screensaver",0
rootarg: db "-root",0
idarg: db "--window-id",0
help_arg: db "--help",0
saver_env: db "XSCREENSAVER_WINDOW",0
foreign_hint: db "SDL_VIDEO_FOREIGN_WINDOW_OPENGL",0
video_env: db "SDL_VIDEODRIVER",0
x11_value: db "x11",0
true_value: db "1",0
window_error: db "Invalid/missing XScreenSaver window ID. Use --window-id 0xID or XSCREENSAVER_WINDOW.",0
windowarg: db `--windowed`,0
snapshotarg: db `--snapshot`,0
backgroundarg: db `--background`,0
ms_scale: dd 0.001
usage: db `JESUS SAVES 1.0.0 | NASM + OpenGL | 4K UHD\nUsage: jesussaves [--cpu|--gpu] [--windowed] [--snapshot|--background]\n       jesussaves [--cpu|--gpu] --screensaver\n       jesussaves [--cpu|--gpu] --window-id 0xID\nEsc exits. FLAME_FRAMES=N limits frames; FLAME_TIME=S sets snapshot time.`,0
framesenv: db `FLAME_FRAMES`,0
previewtime: db `FLAME_TIME`,0
previewrate: dd 60.0
previewmax: dd 60.0
hint: db `SDL_RENDER_SCALE_QUALITY`,0
hintval: db `1`,0
filename: db `flame.ppm`,0
filemode: db `wb`,0
ppmheader: db `P6\n3840 2160\n255\n`
HEADERLEN equ $-ppmheader
errmsg: db `Flame error: %s\n`,0
savedmsg: db `Saved flame.ppm (3840 x 2160).`,0
align 16
global turbulence
turbulence: incbin "assets/turbulence.bin"
section .data
align 8
rng: dd 0x971f253b
framecap: dd 0
windowflags: dd 0x1003
backend_cpu: dd 0
saver_mode: dd 0
foreign_window: dq 0
snapshot_bg: dd 0
gpuclock: dd 0.0
gustphase: dd 0
global tick
tick: dd 0
section .bss
align 64
global heat
heat: resb CELLS*4
rgbrow: resb 3840*3
parse_end: resq 1
event: resb 64
win: resb 8
texture: resb 8
section .text
; Leaf xorshift32; no division, no libc RNG, deterministic preview.
random:
    mov eax, dword [rel rng]
    mov edx,eax
    shl edx,13
    xor eax,edx
    mov edx,eax
    shr edx,17
    xor eax,edx
    mov edx,eax
    shl edx,5
    xor eax,edx
    or eax,1
    mov dword [rel rng],eax
    ret

; Update in place, top to bottom: all samples come from untouched rows.
; Side gutters wrap, removing cold seams at the screen edges.
;
global flame_step
flame_step:
    push rbx
    lea rbx,[rel heat]
    ; Continuously evolving, multiscale fuel; no synchronized square patches.
    call random
    and eax,7
    sub eax,3
    add dword [rel gustphase],eax
    and dword [rel gustphase],127
    inc dword [rel tick]
    mov eax,dword [rel tick]
    shr eax,1
    and eax,255
    shl eax,11
    lea r9,[rel turbulence]
    add r9,rax
    lea r8,[rbx+H*STRIDE+4]
    xor eax,eax
.Lfuel:
    mov edx,dword [rel gustphase]
    shl edx,4
    add edx,eax
    and edx,2047
    movaps xmm0,oword [r9+rdx]
    mulps xmm0,oword [rel fuelgain]
    addps xmm0,oword [rel fuelbase]
    pxor xmm1,xmm1
    maxps xmm0,xmm1
    movups xmm1,oword [r8+rax]
    subps xmm0,xmm1
    mulps xmm0,oword [rel blend]
    addps xmm0,xmm1
    movups oword [r8+rax],xmm0
    movups oword [r8+rax+STRIDE],xmm0
    add eax,16
    cmp eax,W*4
    jb .Lfuel
    lea r8,[rbx+STRIDE]
    mov ecx,H+1
.Lgutters:
    mov eax,dword [r8+W*4]
    mov dword [r8],eax
    mov eax,dword [r8+4]
    mov dword [r8+(W+1)*4],eax
    add r8,STRIDE
    dec ecx
    jnz .Lgutters
    lea r8,[rbx+4]
    mov ecx,H
    pxor xmm6,xmm6
.Lheatrow:
    ; A scrolling flow field bends heat sideways; a decorrelated field cools it.
; Fractional backtracing avoids a regular grid of fixed vertical tongues.
    mov edx,dword [rel tick]
    add edx,ecx
    and edx,255
    shl edx,11
    lea r10,[rel turbulence]
    add r10,rdx
    xor eax,eax
align 16
.Lheatvec:
    mov edx,dword [rel tick]
    shr edx,2
    shl edx,4
    add edx,eax
    and edx,2047
    movaps xmm7,oword [r10+rdx]
    mulps xmm7,oword [rel flowgain]
    addps xmm7,oword [rel flowbias]
    cvttss2si esi,xmm7
    cvtsi2ss xmm4,esi
    subss xmm7,xmm4
    shufps xmm7,xmm7,0
    sub esi,3
    lea esi,[eax+esi*4]
    xor edi,edi
    cmp esi,0
    cmovl esi,edi
    mov edi,W*4-16
    cmp esi,edi
    cmovg esi,edi
    movups xmm0,oword [r8+rsi+STRIDE]
    movups xmm1,oword [r8+rsi+STRIDE+4]
    movups xmm2,oword [r8+rsi+2*STRIDE]
    movups xmm3,oword [r8+rsi+2*STRIDE+4]
    subps xmm1,xmm0
    subps xmm3,xmm2
    mulps xmm1,xmm7
    mulps xmm3,xmm7
    addps xmm0,xmm1
    addps xmm2,xmm3
    addps xmm0,xmm2
    mulps xmm0,oword [rel half]
    add edx,688
    and edx,2047
    movaps xmm5,oword [r10+rdx]
    mulps xmm5,oword [rel coolgain]
    addps xmm5,oword [rel cooling]
    subps xmm0,xmm5
    maxps xmm0,xmm6
    movups oword [r8+rax],xmm0
    add eax,16
    cmp eax,W*4
    jb .Lheatvec
    add r8,STRIDE
    dec ecx
    jnz .Lheatrow
    pop rbx
    ret

global main
main:
    push rbp
    mov rbp,rsp
    push rbx
    push r12
    push r13
    push r14
    ; rsp 16-byte aligned at every external call.
    mov r12d,edi
    mov r13,rsi
    mov ebx,1
.argloop:
    cmp ebx,r12d
    jae .args_done
    mov r14,[r13+rbx*8]
    mov rdi,r14
    lea rsi,[cpuarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_cpu
    mov rdi,r14
    lea rsi,[gpuarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_gpu
    mov rdi,r14
    lea rsi,[windowarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_window
    mov rdi,r14
    lea rsi,[snapshotarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_snapshot
    mov rdi,r14
    lea rsi,[backgroundarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_background
    mov rdi,r14
    lea rsi,[saverarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_saver
    mov rdi,r14
    lea rsi,[rootarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_saver
    mov rdi,r14
    lea rsi,[idarg]
    call strcmp wrt ..plt
    test eax,eax
    jz .arg_id
    mov rdi,r14
    lea rsi,[help_arg]
    call strcmp wrt ..plt
    test eax,eax
    jz .help
    jmp .Lusage
.arg_cpu:
    mov dword [backend_cpu],1
    jmp .arg_next
.arg_gpu:
    mov dword [backend_cpu],0
    jmp .arg_next
.arg_window:
    mov dword [windowflags],2
    jmp .arg_next
.arg_snapshot:
    mov dword [snapshot_bg],2
    jmp .arg_next
.arg_background:
    mov dword [snapshot_bg],1
    jmp .arg_next
.arg_saver:
    mov dword [saver_mode],1
    jmp .arg_next
.arg_id:
    inc ebx
    cmp ebx,r12d
    jae .bad_id
    mov rdi,[r13+rbx*8]
    call parse_window
    test rax,rax
    jz .bad_id
    mov [foreign_window],rax
.arg_next:
    inc ebx
    jmp .argloop
.args_done:
    cmp dword [snapshot_bg],0
    je .check_env
    call save_snapshot
    jmp .Lreturn
.check_env:
    cmp qword [foreign_window],0
    jne .force_x11
    lea rdi,[saver_env]
    call getenv wrt ..plt
    test rax,rax
    jz .check_saver
    mov rdi,rax
    call parse_window
    test rax,rax
    jz .bad_id
    mov [foreign_window],rax
.force_x11:
    lea rdi,[video_env]
    lea rsi,[x11_value]
    mov edx,1
    call SDL_setenv wrt ..plt
    jmp .Linit
.check_saver:
    cmp dword [saver_mode],0
    je .Linit
.bad_id:
    lea rdi,[window_error]
    call puts wrt ..plt
    mov eax,2
    jmp .Lreturn
.help:
    lea rdi,[usage]
    call puts wrt ..plt
    xor eax,eax
    jmp .Lreturn
.Lusage:
    lea rdi,[usage]
    call puts wrt ..plt
    mov eax,2
    jmp .Lreturn
.Linit:
    lea rdi,[rel framesenv]
    call getenv wrt ..plt
    test rax,rax
    jz .Lsdl
    mov rdi,rax
    call atoi wrt ..plt
    test eax,eax
    jle .Lsdl
    mov dword [rel framecap],eax
.Lsdl:
    mov edi,0x20
    call SDL_Init wrt ..plt
    test eax,eax
    js .Lerror
    call SDL_EnableScreenSaver wrt ..plt
    cmp dword [backend_cpu],0
    jne .skip_gpu_config
    call gpu_configure
.skip_gpu_config:
    call SDL_GetPerformanceCounter wrt ..plt
    or eax,1
    mov dword [rel rng],eax
    and eax,65535
    mov dword [rel tick],eax
    lea rdi,[rel hint]
    lea rsi,[rel hintval]
    call SDL_SetHint wrt ..plt
    cmp qword [foreign_window],0
    je .own_window
    cmp dword [backend_cpu],0
    jne .wrap_window
    lea rdi,[foreign_hint]
    lea rsi,[true_value]
    call SDL_SetHint wrt ..plt
    xor edi,edi
    call SDL_GL_LoadLibrary wrt ..plt
    test eax,eax
    js .Lerror
.wrap_window:
    mov rdi,[foreign_window]
    call SDL_CreateWindowFrom wrt ..plt
    jmp .window_created
.own_window:
    cmp dword [backend_cpu],0
    je .window_flags_ready
    and dword [windowflags],~2
.window_flags_ready:
    lea rdi,[rel title]
    mov esi,0x2fff0000
    mov edx,esi
    mov ecx,1024
    mov r8d,720
    mov r9d,dword [rel windowflags]
    call SDL_CreateWindow wrt ..plt
.window_created:
    mov qword [rel win],rax
    test rax,rax
    jz .Lerror
    mov rdi,rax
    cmp dword [backend_cpu],0
    jne .init_cpu
    call gpu_init
    jmp .backend_ready
.init_cpu:
    call cpu_init
.backend_ready:
    test eax,eax
    js .Lerror
    xor edi,edi
    call SDL_ShowCursor wrt ..plt
    ; Warm up so the first presented frame already contains fire.
    mov ebx,200
.Lwarm:
    call flame_step
    dec ebx
    jnz .Lwarm
    xor r12d,r12d
    call SDL_GetTicks wrt ..plt
    mov r14d,eax
.Lframe:
    call SDL_GetTicks wrt ..plt
    mov r13d,eax
.Levents:
    lea rdi,[rel event]
    call SDL_PollEvent wrt ..plt
    test eax,eax
    jz .Ldraw
    mov eax,dword [rel event]
    cmp eax,0x100
    je .Lsuccess
    cmp eax,0x300
    jne .Levents
    cmp dword [rel event+20],27
    je .Lsuccess
    jmp .Levents
.Ldraw:
    call flame_step
    call SDL_GetTicks wrt ..plt
    sub eax,r14d
    cvtsi2ss xmm0,eax
    mulss xmm0,dword [rel ms_scale]
    xor edi,edi
    cmp dword [backend_cpu],0
    jne .draw_cpu
    call gpu_draw
    jmp .draw_ready
.draw_cpu:
    call cpu_draw
.draw_ready:
    test eax,eax
    js .Lerror
    inc r12d
    mov eax,dword [rel framecap]
    test eax,eax
    jz .Lpace
    cmp r12d,eax
    jae .Lsuccess
.Lpace:
    ; Also cap software/no-vsync renderers at approximately 60 fps.
    call SDL_GetTicks wrt ..plt
    sub eax,r13d
    cmp eax,16
    jae .Lframe
    mov edi,16
    sub edi,eax
    call SDL_Delay wrt ..plt
    jmp .Lframe
.Lerror:
    call SDL_GetError wrt ..plt
    mov rdx,rax
    mov rdi,qword [rel stderr]
    lea rsi,[rel errmsg]
    xor eax,eax
    call fprintf wrt ..plt
    mov ebx,1
    jmp .Lcleanup
.Lsuccess:
    xor ebx,ebx
.Lcleanup:
    call cpu_shutdown
    call gpu_shutdown
    mov edi,1
    call SDL_ShowCursor wrt ..plt
.Ldestroy_window:
    mov rdi,qword [rel win]
    test rdi,rdi
    jz .Lquit
    call SDL_DestroyWindow wrt ..plt
.Lquit:
    call SDL_Quit wrt ..plt
    mov eax,ebx
.Lreturn:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Deterministic, headless full-scene preview, useful over SSH.
save_snapshot:
    push rbx
    push r12
    push r13
    mov ebx,240
    lea rdi,[rel previewtime]
    call getenv wrt ..plt
    test rax,rax
    jz .Lsnapwarm
    mov rdi,rax
    xor esi,esi
    call strtof wrt ..plt
    xorps xmm1,xmm1
    maxss xmm0,xmm1
    minss xmm0,dword [rel previewmax]
    movss dword [rel gpuclock],xmm0
    mulss xmm0,dword [rel previewrate]
    cvttss2si eax,xmm0
    add ebx,eax
.Lsnapwarm:
    call flame_step
    dec ebx
    jnz .Lsnapwarm
    cmp dword [backend_cpu],0
    jne .snapshot_cpu
    call gpu_headless
    test eax,eax
    js .Lsnapgpuerror
    movss xmm0,dword [rel gpuclock]
    xor edi,edi
    cmp dword [snapshot_bg],1
    sete dil
    call gpu_draw
    test eax,eax
    js .Lsnapgpuerror
    call gpu_readback
    call gpu_shutdown
    jmp .write_snapshot
.snapshot_cpu:
    movss xmm0,[gpuclock]
    xor edi,edi
    cmp dword [snapshot_bg],1
    sete dil
    call cpu_render
.write_snapshot:
    lea rdi,[rel filename]
    lea rsi,[rel filemode]
    call fopen wrt ..plt
    test rax,rax
    jz .Lfileerror
    mov r12,rax
    lea rdi,[rel ppmheader]
    mov esi,1
    mov edx,HEADERLEN
    mov rcx,r12
    call fwrite wrt ..plt
    cmp eax,HEADERLEN
    jne .Lwriteerror
    xor ebx,ebx
    lea r13,[rel scene]
.Lsnaprow:
    xor ecx,ecx
    lea rdi,[rel rgbrow]
.Lpack:
    mov eax,dword [r13+rcx*4]
    mov byte [rdi+2],al
    shr eax,8
    mov byte [rdi+1],al
    shr eax,8
    mov byte [rdi],al
    add rdi,3
    inc ecx
    cmp ecx,3840
    jb .Lpack
    add r13,3840*4
.Lwriterow:
    lea rdi,[rel rgbrow]
    mov esi,1
    mov edx,3840*3
    mov rcx,r12
    call fwrite wrt ..plt
    cmp eax,3840*3
    jne .Lwriteerror
    inc ebx
    cmp ebx,2160
    jb .Lsnaprow
    mov rdi,r12
    call fclose wrt ..plt
    test eax,eax
    jnz .Lfileerror
    lea rdi,[rel savedmsg]
    call puts wrt ..plt
    xor eax,eax
    jmp .Lsnapdone
.Lwriteerror:
    mov rdi,r12
    call fclose wrt ..plt
    jmp .Lfileerror
.Lsnapgpuerror:
    call SDL_GetError wrt ..plt
    mov rdx,rax
    mov rdi,qword [rel stderr]
    lea rsi,[rel errmsg]
    xor eax,eax
    call fprintf wrt ..plt
    call gpu_shutdown
    mov eax,1
    jmp .Lsnapdone
.Lfileerror:
    lea rdi,[rel filename]
    call perror wrt ..plt
    mov eax,1
.Lsnapdone:
    pop r13
    pop r12
    pop rbx
    ret
; Strict decimal/0x-hex XID parser, zero means invalid.
parse_window:
    sub rsp,8
    cmp byte [rdi],'-'
    je .invalid
    lea rsi,[parse_end]
    xor edx,edx
    call strtoull wrt ..plt
    mov rcx,[parse_end]
    cmp byte [rcx],0
    jne .invalid
    mov rdx,rax
    shr rdx,32
    jnz .invalid
    add rsp,8
    ret
.invalid:
    xor eax,eax
    add rsp,8
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
