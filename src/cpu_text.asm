; SPDX-License-Identifier: GPL-3.0-only
bits 64
default rel
extern compose_backdrop
extern cosf
extern field
extern getenv
extern pixels
extern scene
extern sinf
extern strtof
; Handwritten AMD64/SSE2 orthographic 3-D text renderer.
; Extruded font distance field, chamfer bevel, sphere tracing and gold shading.
; Internal sdf ABI: xmm0=xyz; result xmm0; clobbers xmm1..7, rax,rcx,rdx,r10.
; xmm8..15 and remaining GPRs are preserved by sdf.
;
section .rodata
align 16
abs4: dd 0x7fffffff,0x7fffffff,0x7fffffff,0x7fffffff
neg4: dd 0x80000000,0x80000000,0x80000000,0x80000000
zero4: dd 0.0,0.0,0.0,0.0
c1: dd 1.0
c2: dd 2.0
c7: dd 7.0
c32: dd 32.0
c192: dd 192.0
c383: dd 1534.999
c63: dd 254.999
c4: dd 4.0
c707: dd 0.70710678
c_eps: dd 0.09
c_normal: dd 0.35
c_step: dd 0.72
c_scale: dd 6.6
c_invscale: dd 0.1515151515
c_start: dd -205.0
c_limit: dd 410.0
c_dt: dd 0.0166666667
c_yawrate: dd 0.43
c_yawstart: dd -0.38
c_pitchrate: dd 0.67
c_pitchgain: dd 0.4
c_pitchbase: dd -0.2
c_xrate: dd 0.29
c_yrate: dd 0.41
c_xgain: dd 750.0
c_reflectscale: dd 0.1333333333
c_ygain: dd 354.0
c_xbase: dd 1920.0
c_ybase: dd 600.0
c_pad: dd 3.0
c_bias: dd 0.28
c_slope: dd 0.18
c_facewarp: dd 0.012
c_xwarp: dd 0.0015
c_band: dd 95.0
c_ambient: dd 0.27
c_diffuse: dd 0.43
c_spec: dd 1.3
c_light: dd -0.8
c_255: dd 255.0
c_182: dd 182.0
c_38: dd 38.0
c_45: dd 45.0
c_150: dd 150.0
c_fire: dd 0.25
poseenv: db `FLAME_TIME`,0
align 16

section .data
global clock_started
clock_started: dd 0
global animtime
animtime: dd 0.0
section .bss
align 64

align 16
axisx: resb 16
axisy: resb 16
axisz: resb 16
centerx: resb 4
centery: resb 4
cy: resb 4
sy: resb 4
cp: resb 4
sinpitch: resb 4
xmin: resb 4
xmax: resb 4
ymin: resb 4
ymax: resb 4
section .text
; 2-D bilinear SDF lookup + extruded, chamfered depth.
sdf:
    movaps xmm7,xmm0
    movaps xmm1,xmm0
    shufps xmm1,xmm1,0x55
    addss xmm0,dword [rel c192]
    addss xmm1,dword [rel c32]
    mulss xmm0,dword [rel c4]
    mulss xmm1,dword [rel c4]
    xorps xmm6,xmm6
    maxss xmm0,xmm6
    maxss xmm1,xmm6
    minss xmm0,dword [rel c383]
    minss xmm1,dword [rel c63]
    cvttss2si eax,xmm0
    cvttss2si ecx,xmm1
    cvtsi2ss xmm2,eax
    cvtsi2ss xmm3,ecx
    subss xmm0,xmm2
    subss xmm1,xmm3
    imul ecx,1536
    add eax,ecx
    lea r10,[rel field]
    movss xmm2,dword [r10+rax*4]
    movss xmm3,dword [r10+rax*4+4]
    subss xmm3,xmm2
    mulss xmm3,xmm0
    addss xmm2,xmm3
    movss xmm3,dword [r10+rax*4+6144]
    movss xmm4,dword [r10+rax*4+6148]
    subss xmm4,xmm3
    mulss xmm4,xmm0
    addss xmm3,xmm4
    subss xmm3,xmm2
    mulss xmm3,xmm1
    addss xmm2,xmm3
    ; Conservative distance outside the finite lookup rectangle.
    movaps xmm3,xmm7
    andps xmm3,oword [rel abs4]
    movaps xmm4,xmm3
    shufps xmm4,xmm4,0x55
    subss xmm3,dword [rel c192]
    subss xmm4,dword [rel c32]
    maxss xmm2,xmm3
    maxss xmm2,xmm4
    shufps xmm7,xmm7,0xaa
    andps xmm7,oword [rel abs4]
    subss xmm7,dword [rel c7]
    movaps xmm0,xmm2
    maxss xmm0,xmm7
    addss xmm2,xmm7
    addss xmm2,dword [rel c2]
    mulss xmm2,dword [rel c707]
    maxss xmm0,xmm2
    ret

; Returns an opaque 3840x2160 composite. No SDL or GPU needed for a snapshot.
global compose_scene
compose_scene:
    push rbp
    mov rbp,rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp,40
    call compose_backdrop
    cmp dword [rel clock_started],0
    jne .Ltime_ready
    mov dword [rel clock_started],1
    lea rdi,[rel poseenv]
    call getenv wrt ..plt
    test rax,rax
    jz .Ltime_ready
    mov rdi,rax
    xor esi,esi
    call strtof wrt ..plt
    ; Ignore NaN/Inf input.
    movd eax,xmm0
    and eax,0x7f800000
    cmp eax,0x7f800000
    je .Ltime_ready
    movss dword [rel animtime],xmm0
.Ltime_ready:
    movss xmm0,dword [rel animtime]
    mulss xmm0,dword [rel c_yawrate]
    addss xmm0,dword [rel c_yawstart]
    movss dword [rsp],xmm0
    call cosf wrt ..plt
    movss dword [rel cy],xmm0
    movss xmm0,dword [rsp]
    call sinf wrt ..plt
    movss dword [rel sy],xmm0
    movss xmm0,dword [rel animtime]
    mulss xmm0,dword [rel c_pitchrate]
    call sinf wrt ..plt
    mulss xmm0,dword [rel c_pitchgain]
    addss xmm0,dword [rel c_pitchbase]
    movss dword [rsp],xmm0
    call cosf wrt ..plt
    movss dword [rel cp],xmm0
    movss xmm0,dword [rsp]
    call sinf wrt ..plt
    movss dword [rel sinpitch],xmm0
    movss xmm0,dword [rel animtime]
    mulss xmm0,dword [rel c_xrate]
    call sinf wrt ..plt
    mulss xmm0,dword [rel c_xgain]
    addss xmm0,dword [rel c_xbase]
    movss dword [rel centerx],xmm0
    movss xmm0,dword [rel animtime]
    mulss xmm0,dword [rel c_yrate]
    call sinf wrt ..plt
    mulss xmm0,dword [rel c_ygain]
    addss xmm0,dword [rel c_ybase]
    movss dword [rel centery],xmm0
    movss xmm0,dword [rel animtime]
    addss xmm0,dword [rel c_dt]
    movss dword [rel animtime],xmm0
    ; Inverse rotation columns, yaw about Y and pitch about X.
    movss xmm0,dword [rel cy]
    movss dword [rel axisx],xmm0
    movss xmm1,dword [rel sy]
    movaps xmm2,xmm1
    mulss xmm1,dword [rel sinpitch]
    mulss xmm2,dword [rel cp]
    movss dword [rel axisx+4],xmm1
    movss dword [rel axisx+8],xmm2
    movss xmm1,dword [rel cp]
    movss dword [rel axisy+4],xmm1
    movss xmm2,dword [rel sinpitch]
    xorps xmm2,oword [rel neg4]
    movss dword [rel axisy+8],xmm2
    movss xmm2,dword [rel sy]
    xorps xmm2,oword [rel neg4]
    movss dword [rel axisz],xmm2
    movaps xmm1,xmm0
    mulss xmm0,dword [rel sinpitch]
    mulss xmm1,dword [rel cp]
    movss dword [rel axisz+4],xmm0
    movss dword [rel axisz+8],xmm1
    ; Projected box bounds: only rays inside this rectangle are traced.
    movaps xmm0,oword [rel axisx]
    call extent
    movss xmm1,dword [rel centerx]
    movaps xmm2,xmm1
    subss xmm1,xmm0
    addss xmm2,xmm0
    cvttss2si eax,xmm1
    cvttss2si ecx,xmm2
    xor edx,edx
    cmp eax,0
    cmovl eax,edx
    mov edx,3839
    cmp ecx,3839
    cmovg ecx,edx
    mov dword [rel xmin],eax
    mov dword [rel xmax],ecx
    movaps xmm0,oword [rel axisy]
    call extent
    movss xmm1,dword [rel centery]
    movaps xmm2,xmm1
    subss xmm1,xmm0
    addss xmm2,xmm0
    cvttss2si eax,xmm1
    cvttss2si ecx,xmm2
    xor edx,edx
    cmp eax,0
    cmovl eax,edx
    mov edx,1199
    cmp ecx,1199
    cmovg ecx,edx
    mov dword [rel ymin],eax
    mov dword [rel ymax],ecx
    mov r12d,eax
    lea r15,[rel scene]
.Ltextrow:
    cvtsi2ss xmm0,r12d
    subss xmm0,dword [rel centery]
    mulss xmm0,dword [rel c_invscale]
    shufps xmm0,xmm0,0
    mulps xmm0,oword [rel axisy]
    movaps xmm12,xmm0
    movss xmm0,dword [rel c_start]
    shufps xmm0,xmm0,0
    mulps xmm0,oword [rel axisz]
    addps xmm12,xmm0
    mov ebx,dword [rel xmin]
.Ltextpixel:
    cvtsi2ss xmm0,ebx
    subss xmm0,dword [rel centerx]
    mulss xmm0,dword [rel c_invscale]
    shufps xmm0,xmm0,0
    mulps xmm0,oword [rel axisx]
    addps xmm0,xmm12
    movaps xmm8,xmm0
    movaps xmm9,oword [rel axisz]
    xorps xmm10,xmm10
    mov r14d,100
.Lmarch:
    movaps xmm0,xmm8
    call sdf
    comiss xmm0,dword [rel c_eps]
    jb .Lhit
    mulss xmm0,dword [rel c_step]
    addss xmm10,xmm0
    comiss xmm10,dword [rel c_limit]
    ja .Lnextpixel
    shufps xmm0,xmm0,0
    mulps xmm0,xmm9
    addps xmm8,xmm0
    dec r14d
    jnz .Lmarch
    jmp .Lnextpixel
.Lhit:
    ; Central-difference surface normal: bevels reflect differently from faces.
    movaps xmm0,xmm8
    addss xmm0,dword [rel c_normal]
    call sdf
    movaps xmm13,xmm0
    movaps xmm0,xmm8
    subss xmm0,dword [rel c_normal]
    call sdf
    subss xmm13,xmm0
    movss dword [rsp+16],xmm13
    movaps xmm0,xmm8
    xorps xmm1,xmm1
    movss xmm1,dword [rel c_normal]
    pslldq xmm1,4
    addps xmm0,xmm1
    call sdf
    movaps xmm13,xmm0
    movaps xmm0,xmm8
    xorps xmm1,xmm1
    movss xmm1,dword [rel c_normal]
    pslldq xmm1,4
    subps xmm0,xmm1
    call sdf
    subss xmm13,xmm0
    movss dword [rsp+20],xmm13
    movaps xmm0,xmm8
    xorps xmm1,xmm1
    movss xmm1,dword [rel c_normal]
    pslldq xmm1,8
    addps xmm0,xmm1
    call sdf
    movaps xmm13,xmm0
    movaps xmm0,xmm8
    xorps xmm1,xmm1
    movss xmm1,dword [rel c_normal]
    pslldq xmm1,8
    subps xmm0,xmm1
    call sdf
    subss xmm13,xmm0
    movss dword [rsp+24],xmm13
    mov dword [rsp+28],0
    movups xmm13,oword [rsp+16]
    movaps xmm0,xmm13
    mulps xmm0,xmm0
    call sum3
    maxss xmm0,dword [rel c_eps]
    sqrtss xmm0,xmm0
    shufps xmm0,xmm0,0
    divps xmm13,xmm0
    movaps xmm0,xmm13
    mulps xmm0,oword [rel axisx]
    call sum3
    movaps xmm14,xmm0 ; screen normal x
    movaps xmm0,xmm13
    mulps xmm0,oword [rel axisy]
    call sum3
    movaps xmm15,xmm0 ; screen normal y
    movaps xmm0,xmm13
    mulps xmm0,oword [rel axisz]
    call sum3
    ; Reflection R=2*N*Nz - V for V=(0,0,1).
; Studio band + warm lower environment, modulated across face position.
    movaps xmm1,xmm0
    mulss xmm1,dword [rel c2]
    mulss xmm14,xmm1
    mulss xmm15,xmm1
    movaps xmm2,xmm14
    mulss xmm2,dword [rel c_slope]
    addss xmm2,xmm15
    addss xmm2,dword [rel c_bias]
    movaps xmm3,xmm8
    shufps xmm3,xmm3,0x55
    mulss xmm3,dword [rel c_facewarp]
    addss xmm2,xmm3
    movaps xmm3,xmm8
    mulss xmm3,dword [rel c_xwarp]
    addss xmm2,xmm3
    mulss xmm2,xmm2
    mulss xmm2,dword [rel c_band]
    addss xmm2,dword [rel c1]
    movss xmm3,dword [rel c1]
    divss xmm3,xmm2 ; bright studio reflection
    mulss xmm0,dword [rel c_light]
    xorps xmm4,xmm4
    maxss xmm0,xmm4
    mulss xmm0,dword [rel c_diffuse]
    addss xmm0,dword [rel c_ambient]
    movaps xmm2,xmm3
    mulss xmm2,dword [rel c_spec]
    addss xmm0,xmm2
    ; Warm reflection of the actual current fire, sampled by reflected X.
    mulss xmm14,dword [rel c_xgain]
    addss xmm14,dword [rel centerx]
    mulss xmm14,dword [rel c_reflectscale]
    cvttss2si eax,xmm14
    and eax,511
    lea r10,[rel pixels]
    mov edx,dword [r10+rax*4+512*145*4]
    shr edx,8
    and edx,255
    cvtsi2ss xmm1,edx
    divss xmm1,dword [rel c_255]
    mulss xmm1,dword [rel c_fire]
    addss xmm0,xmm1
    movaps xmm1,xmm0
    movaps xmm2,xmm0
    mulss xmm0,dword [rel c_255]
    mulss xmm1,dword [rel c_182]
    mulss xmm2,dword [rel c_38]
    movaps xmm4,xmm3
    mulss xmm4,dword [rel c_45]
    addss xmm1,xmm4
    mulss xmm3,dword [rel c_150]
    addss xmm2,xmm3
    minss xmm0,dword [rel c_255]
    minss xmm1,dword [rel c_255]
    minss xmm2,dword [rel c_255]
    cvttss2si eax,xmm0
    cvttss2si ecx,xmm1
    cvttss2si edx,xmm2
    shl eax,16
    shl ecx,8
    or eax,ecx
    or eax,edx
    or eax,0xff000000
    mov ecx,r12d
    imul ecx,3840
    add ecx,ebx
    mov dword [r15+rcx*4],eax
.Lnextpixel:
    inc ebx
    cmp ebx,dword [rel xmax]
    jle .Ltextpixel
    inc r12d
    cmp r12d,dword [rel ymax]
    jle .Ltextrow
    lea rax,[rel scene]
    add rsp,40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; xyz dot reduction, baseline SSE2.
sum3:
    movaps xmm1,xmm0
    shufps xmm1,xmm1,0x55
    addss xmm0,xmm1
    movaps xmm1,xmm0
    shufps xmm1,xmm1,0xaa
    addss xmm0,xmm1
    ret
extent:
    andps xmm0,oword [rel abs4]
    movaps xmm1,xmm0
    movaps xmm2,xmm0
    shufps xmm1,xmm1,0x55
    shufps xmm2,xmm2,0xaa
    mulss xmm0,dword [rel c192]
    mulss xmm1,dword [rel c32]
    mulss xmm2,dword [rel c7]
    addss xmm0,xmm1
    addss xmm0,xmm2
    mulss xmm0,dword [rel c_scale]
    addss xmm0,dword [rel c_pad]
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
