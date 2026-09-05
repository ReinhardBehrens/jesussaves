; SPDX-License-Identifier: GPL-3.0-only
bits 64
default rel
extern SDL_GL_CreateContext
extern SDL_GL_DeleteContext
extern SDL_GL_GetDrawableSize
extern SDL_GL_SetAttribute
extern SDL_GL_SetSwapInterval
extern SDL_GL_SwapWindow
extern SDL_SetError
extern background_data
extern eglBindAPI
extern eglChooseConfig
extern eglCreateContext
extern eglCreatePbufferSurface
extern eglDestroyContext
extern eglDestroySurface
extern eglGetPlatformDisplay
extern eglInitialize
extern eglMakeCurrent
extern eglTerminate
extern field
extern glActiveTexture
extern glAttachShader
extern glBindFramebuffer
extern glBindTexture
extern glBindVertexArray
extern glBlitFramebuffer
extern glCheckFramebufferStatus
extern glCompileShader
extern glCreateProgram
extern glCreateShader
extern glDeleteShader
extern glDrawArrays
extern glFramebufferTexture2D
extern glGenFramebuffers
extern glGenTextures
extern glGenVertexArrays
extern glGetError
extern glGetProgramiv
extern glGetShaderInfoLog
extern glGetShaderiv
extern glGetUniformLocation
extern glLinkProgram
extern glPixelStorei
extern glReadPixels
extern glShaderSource
extern glTexImage2D
extern glTexParameteri
extern glTexSubImage2D
extern glUniform1f
extern glUniform1i
extern glUseProgram
extern glViewport
extern heat
extern scene
; OpenGL 3.3 presentation from AMD64 assembly. Always renders to a 4K FBO.
; GLSL executes text ray tracing and fine turbulent emission on the GPU.
; EGL surfaceless context provides the exact same renderer for snapshots.
;
section .rodata
vertex_source: incbin "shaders/scene.vert"
db 0
fragment_source: incbin "shaders/scene.frag"
db 0
align 8
vertex_ptr: dq vertex_source
fragment_ptr: dq fragment_source
name_heaven: db `heaven`,0
name_heat: db `heatMap`,0
name_text: db `lettering`,0
name_time: db `seconds`,0
name_bg: db `backgroundOnly`,0
errfmt: db `%s`,0
errgpu: db `OpenGL 3.3 / 4K framebuffer initialization failed`,0
egl_attrs: dd 0x3033,1,0x3040,8,0x3024,8,0x3023,8,0x3022,8,0x3038
egl_surface_attrs: dd 0x3057,1,0x3056,1,0x3038
egl_context_attrs: dd 0x3098,3,0x30fb,3,0x30fd,1,0x3038
%define BG_W 3840
%define BG_H 2160
section .bss
align 16
window: resb 8
context: resb 8
egl_display: resb 8
egl_config: resb 8
egl_surface: resb 8
egl_context: resb 8
egl_count: resb 4
program: resb 4
textures: resb 16
fbo: resb 4
vao: resb 4
status: resb 4
uniform_time: resb 4
uniform_bg: resb 4
draw_width: resb 4
draw_height: resb 4
shader_log: resb 4096
readback: resb 3840*2160*4
section .text
global gpu_configure
gpu_configure:
    sub rsp,8
    mov edi,17
    mov esi,3
    call SDL_GL_SetAttribute wrt ..plt
    mov edi,18
    mov esi,3
    call SDL_GL_SetAttribute wrt ..plt
    mov edi,21
    mov esi,1
    call SDL_GL_SetAttribute wrt ..plt
    add rsp,8
    ret
global gpu_init
gpu_init:
    sub rsp,8
    mov qword [rel window],rdi
    call SDL_GL_CreateContext wrt ..plt
    mov qword [rel context],rax
    test rax,rax
    jz .Linit_fail
    mov edi,1
    call SDL_GL_SetSwapInterval wrt ..plt
    call gpu_common
    add rsp,8
    ret
.Linit_fail:
    mov eax,-1
    add rsp,8
    ret
global gpu_headless
gpu_headless:
    sub rsp,8
    mov edi,0x31dd ; EGL_PLATFORM_SURFACELESS_MESA
    xor esi,esi
    xor edx,edx
    call eglGetPlatformDisplay wrt ..plt
    mov qword [rel egl_display],rax
    test rax,rax
    jz .Lheadless_fail
    mov rdi,rax
    xor esi,esi
    xor edx,edx
    call eglInitialize wrt ..plt
    test eax,eax
    jz .Lheadless_fail
    mov edi,0x30a2
    call eglBindAPI wrt ..plt
    test eax,eax
    jz .Lheadless_fail
    mov rdi,qword [rel egl_display]
    lea rsi,[rel egl_attrs]
    lea rdx,[rel egl_config]
    mov ecx,1
    lea r8,[rel egl_count]
    call eglChooseConfig wrt ..plt
    test eax,eax
    jz .Lheadless_fail
    cmp dword [rel egl_count],0
    je .Lheadless_fail
    mov rdi,qword [rel egl_display]
    mov rsi,qword [rel egl_config]
    lea rdx,[rel egl_surface_attrs]
    call eglCreatePbufferSurface wrt ..plt
    mov qword [rel egl_surface],rax
    test rax,rax
    jz .Lheadless_fail
    mov rdi,qword [rel egl_display]
    mov rsi,qword [rel egl_config]
    xor edx,edx
    lea rcx,[rel egl_context_attrs]
    call eglCreateContext wrt ..plt
    mov qword [rel egl_context],rax
    test rax,rax
    jz .Lheadless_fail
    mov rdi,qword [rel egl_display]
    mov rsi,qword [rel egl_surface]
    mov rdx,rsi
    mov rcx,rax
    call eglMakeCurrent wrt ..plt
    test eax,eax
    jz .Lheadless_fail
    call gpu_common
    add rsp,8
    ret
.Lheadless_fail:
    call gpu_error
    add rsp,8
    ret

; Compile one stage, returning shader id or zero and an SDL diagnostic.
compile_shader:
    push rbx
    push r12
    sub rsp,8
    mov r12,rsi
    call glCreateShader wrt ..plt
    mov ebx,eax
    mov edi,eax
    mov esi,1
    mov rdx,r12
    xor ecx,ecx
    call glShaderSource wrt ..plt
    mov edi,ebx
    call glCompileShader wrt ..plt
    mov edi,ebx
    mov esi,0x8b81
    lea rdx,[rel status]
    call glGetShaderiv wrt ..plt
    cmp dword [rel status],0
    je .Lshader_fail
    mov eax,ebx
    jmp .Lshader_done
.Lshader_fail:
    mov edi,ebx
    mov esi,4096
    xor edx,edx
    lea rcx,[rel shader_log]
    call glGetShaderInfoLog wrt ..plt
    lea rdi,[rel errfmt]
    lea rsi,[rel shader_log]
    xor eax,eax
    call SDL_SetError wrt ..plt
    mov edi,ebx
    call glDeleteShader wrt ..plt
    xor eax,eax
.Lshader_done:
    add rsp,8
    pop r12
    pop rbx
    ret



gpu_common:
    push rbx
    push r12
    sub rsp,8
    mov edi,0x8b31
    lea rsi,[rel vertex_ptr]
    call compile_shader
    test eax,eax
    jz .Lcommon_fail
    mov ebx,eax
    mov edi,0x8b30
    lea rsi,[rel fragment_ptr]
    call compile_shader
    test eax,eax
    jz .Lcommon_fail
    mov r12d,eax
    call glCreateProgram wrt ..plt
    mov dword [rel program],eax
    mov edi,eax
    mov esi,ebx
    call glAttachShader wrt ..plt
    mov edi,dword [rel program]
    mov esi,r12d
    call glAttachShader wrt ..plt
    mov edi,dword [rel program]
    call glLinkProgram wrt ..plt
    mov edi,ebx
    call glDeleteShader wrt ..plt
    mov edi,r12d
    call glDeleteShader wrt ..plt
    mov edi,dword [rel program]
    mov esi,0x8b82
    lea rdx,[rel status]
    call glGetProgramiv wrt ..plt
    cmp dword [rel status],0
    je .Lcommon_generic_fail
    mov edi,dword [rel program]
    call glUseProgram wrt ..plt
    mov edi,dword [rel program]
    lea rsi,[rel name_heaven]
    call glGetUniformLocation wrt ..plt
    mov edi,eax
    xor esi,esi
    call glUniform1i wrt ..plt
    mov edi,dword [rel program]
    lea rsi,[rel name_heat]
    call glGetUniformLocation wrt ..plt
    mov edi,eax
    mov esi,1
    call glUniform1i wrt ..plt
    mov edi,dword [rel program]
    lea rsi,[rel name_text]
    call glGetUniformLocation wrt ..plt
    mov edi,eax
    mov esi,2
    call glUniform1i wrt ..plt
    mov edi,dword [rel program]
    lea rsi,[rel name_time]
    call glGetUniformLocation wrt ..plt
    mov dword [rel uniform_time],eax
    mov edi,dword [rel program]
    lea rsi,[rel name_bg]
    call glGetUniformLocation wrt ..plt
    mov dword [rel uniform_bg],eax
    mov edi,0x84c0+0
    call glActiveTexture wrt ..plt
    mov edi,1
    lea rsi,[rel textures+4*0]
    call glGenTextures wrt ..plt
    mov edi,0x0de1
    mov esi,dword [rel textures+4*0]
    call glBindTexture wrt ..plt
    mov edi,0x0de1
    mov esi,0x2801
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2800
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2802
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2803
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    xor esi,esi
    mov edx,0x8058
    mov ecx,BG_W
    mov r8d,BG_H
    xor r9d,r9d
    sub rsp,32
    mov qword [rsp],0x80e1
    mov qword [rsp+8],0x1401
    lea rax,[rel background_data]
    mov qword [rsp+16],rax

    call glTexImage2D wrt ..plt
    add rsp,32

    mov edi,0x84c0+1
    call glActiveTexture wrt ..plt
    mov edi,1
    lea rsi,[rel textures+4*1]
    call glGenTextures wrt ..plt
    mov edi,0x0de1
    mov esi,dword [rel textures+4*1]
    call glBindTexture wrt ..plt
    mov edi,0x0de1
    mov esi,0x2801
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2800
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2802
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2803
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    xor esi,esi
    mov edx,0x822e
    mov ecx,512
    mov r8d,160
    xor r9d,r9d
    sub rsp,32
    mov qword [rsp],0x1903
    mov qword [rsp+8],0x1406
    mov qword [rsp+16],0

    call glTexImage2D wrt ..plt
    add rsp,32

    mov edi,0x84c0+2
    call glActiveTexture wrt ..plt
    mov edi,1
    lea rsi,[rel textures+4*2]
    call glGenTextures wrt ..plt
    mov edi,0x0de1
    mov esi,dword [rel textures+4*2]
    call glBindTexture wrt ..plt
    mov edi,0x0de1
    mov esi,0x2801
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2800
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2802
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2803
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    xor esi,esi
    mov edx,0x822e
    mov ecx,1536
    mov r8d,256
    xor r9d,r9d
    sub rsp,32
    mov qword [rsp],0x1903
    mov qword [rsp+8],0x1406
    lea rax,[rel field]
    mov qword [rsp+16],rax

    call glTexImage2D wrt ..plt
    add rsp,32

    mov edi,0x84c0+3
    call glActiveTexture wrt ..plt
    mov edi,1
    lea rsi,[rel textures+4*3]
    call glGenTextures wrt ..plt
    mov edi,0x0de1
    mov esi,dword [rel textures+4*3]
    call glBindTexture wrt ..plt
    mov edi,0x0de1
    mov esi,0x2801
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2800
    mov edx,0x2601
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2802
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    mov esi,0x2803
    mov edx,0x812f
    call glTexParameteri wrt ..plt
    mov edi,0x0de1
    xor esi,esi
    mov edx,0x8058
    mov ecx,3840
    mov r8d,2160
    xor r9d,r9d
    sub rsp,32
    mov qword [rsp],0x1908
    mov qword [rsp+8],0x1401
    mov qword [rsp+16],0

    call glTexImage2D wrt ..plt
    add rsp,32

    mov edi,1
    lea rsi,[rel fbo]
    call glGenFramebuffers wrt ..plt
    mov edi,0x8d40
    mov esi,dword [rel fbo]
    call glBindFramebuffer wrt ..plt
    mov edi,0x8d40
    mov esi,0x8ce0
    mov edx,0x0de1
    mov ecx,dword [rel textures+12]
    xor r8d,r8d
    call glFramebufferTexture2D wrt ..plt
    mov edi,0x8d40
    call glCheckFramebufferStatus wrt ..plt
    cmp eax,0x8cd5
    jne .Lcommon_generic_fail
    mov edi,1
    lea rsi,[rel vao]
    call glGenVertexArrays wrt ..plt
    mov edi,dword [rel vao]
    call glBindVertexArray wrt ..plt
    xor eax,eax
    jmp .Lcommon_done
.Lcommon_generic_fail:
    call gpu_error
.Lcommon_fail:
    mov eax,-1
.Lcommon_done:
    add rsp,8
    pop r12
    pop rbx
    ret

gpu_error:
    sub rsp,8
    lea rdi,[rel errgpu]
    xor eax,eax
    call SDL_SetError wrt ..plt
    mov eax,-1
    add rsp,8
    ret

; xmm0=time in seconds; edi=background-only.
global gpu_draw
gpu_draw:
    sub rsp,24
    mov dword [rsp+8],edi
    movss dword [rsp+12],xmm0
    mov edi,dword [rel program]
    call glUseProgram wrt ..plt
    mov edi,dword [rel uniform_time]
    movss xmm0,dword [rsp+12]
    call glUniform1f wrt ..plt
    mov edi,dword [rel uniform_bg]
    mov esi,dword [rsp+8]
    call glUniform1i wrt ..plt
    mov edi,0x84c1
    call glActiveTexture wrt ..plt
    mov edi,0x0de1
    mov esi,dword [rel textures+4]
    call glBindTexture wrt ..plt
    mov edi,0x0cf2 ; GL_UNPACK_ROW_LENGTH
    mov esi,514
    call glPixelStorei wrt ..plt
    mov edi,0x0de1
    xor esi,esi
    xor edx,edx
    xor ecx,ecx
    mov r8d,512
    mov r9d,160
    sub rsp,32
    mov qword [rsp],0x1903
    mov qword [rsp+8],0x1406
    lea rax,[rel heat+4]
    mov qword [rsp+16],rax
    call glTexSubImage2D wrt ..plt
    add rsp,32
    mov edi,0x0cf2
    xor esi,esi
    call glPixelStorei wrt ..plt
    mov edi,0x8d40
    mov esi,dword [rel fbo]
    call glBindFramebuffer wrt ..plt
    xor edi,edi
    xor esi,esi
    mov edx,3840
    mov ecx,2160
    call glViewport wrt ..plt
    mov edi,dword [rel vao]
    call glBindVertexArray wrt ..plt
    mov edi,4
    xor esi,esi
    mov edx,3
    call glDrawArrays wrt ..plt
    cmp qword [rel window],0
    je .Ldraw_done
    mov rdi,qword [rel window]
    lea rsi,[rel draw_width]
    lea rdx,[rel draw_height]
    call SDL_GL_GetDrawableSize wrt ..plt
    mov edi,0x8ca9 ; DRAW_FRAMEBUFFER
    xor esi,esi
    call glBindFramebuffer wrt ..plt
    xor edi,edi
    xor esi,esi
    mov edx,3840
    mov ecx,2160
    xor r8d,r8d
    xor r9d,r9d
    sub rsp,32
    mov eax,dword [rel draw_width]
    mov qword [rsp],rax
    mov eax,dword [rel draw_height]
    mov qword [rsp+8],rax
    mov qword [rsp+16],0x4000
    mov qword [rsp+24],0x2601
    call glBlitFramebuffer wrt ..plt
    add rsp,32
    mov rdi,qword [rel window]
    call SDL_GL_SwapWindow wrt ..plt
.Ldraw_done:
    call glGetError wrt ..plt
    test eax,eax
    jz .Ldraw_ok
    call gpu_error
.Ldraw_ok:
    add rsp,24
    ret

global gpu_readback
gpu_readback:
    sub rsp,8
    mov edi,0x8d40
    mov esi,dword [rel fbo]
    call glBindFramebuffer wrt ..plt
    xor edi,edi
    xor esi,esi
    mov edx,3840
    mov ecx,2160
    mov r8d,0x80e1
    mov r9d,0x1401
    sub rsp,16
    lea rax,[rel readback]
    mov qword [rsp],rax
    call glReadPixels wrt ..plt
    add rsp,16
    lea rdi,[rel scene]
    lea rsi,[rel readback+3840*2159*4]
    mov edx,2160
.Lflip:
    mov ecx,3840/2
    rep movsq
    sub rsi,3840*8
    dec edx
    jnz .Lflip
    add rsp,8
    ret
global gpu_shutdown
gpu_shutdown:
    sub rsp,8
    mov rdi,qword [rel context]
    test rdi,rdi
    jz .Legl_cleanup
    call SDL_GL_DeleteContext wrt ..plt
.Legl_cleanup:
    mov rdi,qword [rel egl_display]
    test rdi,rdi
    jz .Lshutdown_done
    xor esi,esi
    xor edx,edx
    xor ecx,ecx
    call eglMakeCurrent wrt ..plt
    mov rdi,qword [rel egl_display]
    mov rsi,qword [rel egl_context]
    call eglDestroyContext wrt ..plt
    mov rdi,qword [rel egl_display]
    mov rsi,qword [rel egl_surface]
    call eglDestroySurface wrt ..plt
    mov rdi,qword [rel egl_display]
    call eglTerminate wrt ..plt
.Lshutdown_done:
    add rsp,8
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
