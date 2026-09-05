#!/usr/bin/env python3
"""Generate COFF sources and typed SysV-to-Win64 library bridges.
The rendering code remains shared NASM; generated files stay in build/windows.
"""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
out=root/'build/windows';out.mkdir(parents=True,exist_ok=True)
# Return type | API | argument types (names are generated).
spec='''int|puts|const char*
int|strcmp|const char*,const char*
char*|getenv|const char*
int|atoi|const char*
float|strtof|const char*,char**
unsigned long long|strtoull|const char*,char**,int
FILE*|fopen|const char*,const char*
int|fclose|FILE*
size_t|fwrite|const void*,size_t,size_t,FILE*
void|perror|const char*
float|sinf|float
float|cosf|float
int|SDL_Init|Uint32
void|SDL_EnableScreenSaver|
void|SDL_Quit|
Uint64|SDL_GetPerformanceCounter|
Uint32|SDL_GetTicks|
void|SDL_Delay|Uint32
const char*|SDL_GetError|
SDL_bool|SDL_SetHint|const char*,const char*
int|SDL_setenv|const char*,const char*,int
int|SDL_ShowCursor|int
SDL_Window*|SDL_CreateWindow|const char*,int,int,int,int,Uint32
void|SDL_DestroyWindow|SDL_Window*
int|SDL_GL_LoadLibrary|const char*
SDL_GLContext|SDL_GL_CreateContext|SDL_Window*
void|SDL_GL_DeleteContext|SDL_GLContext
void|SDL_GL_GetDrawableSize|SDL_Window*,int*,int*
int|SDL_GL_SetAttribute|SDL_GLattr,int
int|SDL_GL_SetSwapInterval|int
void|SDL_GL_SwapWindow|SDL_Window*
SDL_Renderer*|SDL_CreateRenderer|SDL_Window*,int,Uint32
SDL_Texture*|SDL_CreateTexture|SDL_Renderer*,Uint32,int,int,int
int|SDL_UpdateTexture|SDL_Texture*,const SDL_Rect*,const void*,int
int|SDL_RenderCopy|SDL_Renderer*,SDL_Texture*,const SDL_Rect*,const SDL_Rect*
void|SDL_RenderPresent|SDL_Renderer*
void|SDL_DestroyTexture|SDL_Texture*
void|SDL_DestroyRenderer|SDL_Renderer*
void|glActiveTexture|GLenum
void|glAttachShader|GLuint,GLuint
void|glBindFramebuffer|GLenum,GLuint
void|glBindTexture|GLenum,GLuint
void|glBindVertexArray|GLuint
void|glBlitFramebuffer|GLint,GLint,GLint,GLint,GLint,GLint,GLint,GLint,GLbitfield,GLenum
GLenum|glCheckFramebufferStatus|GLenum
void|glCompileShader|GLuint
GLuint|glCreateProgram|
GLuint|glCreateShader|GLenum
void|glDeleteShader|GLuint
void|glDrawArrays|GLenum,GLint,GLsizei
void|glFramebufferTexture2D|GLenum,GLenum,GLenum,GLuint,GLint
void|glGenFramebuffers|GLsizei,GLuint*
void|glGenTextures|GLsizei,GLuint*
void|glGenVertexArrays|GLsizei,GLuint*
GLenum|glGetError|
void|glGetProgramiv|GLuint,GLenum,GLint*
void|glGetShaderInfoLog|GLuint,GLsizei,GLsizei*,GLchar*
void|glGetShaderiv|GLuint,GLenum,GLint*
GLint|glGetUniformLocation|GLuint,const GLchar*
void|glLinkProgram|GLuint
void|glPixelStorei|GLenum,GLint
void|glReadPixels|GLint,GLint,GLsizei,GLsizei,GLenum,GLenum,void*
void|glShaderSource|GLuint,GLsizei,const GLchar* const*,const GLint*
void|glTexImage2D|GLenum,GLint,GLint,GLsizei,GLsizei,GLint,GLenum,GLenum,const void*
void|glTexParameteri|GLenum,GLenum,GLint
void|glTexSubImage2D|GLenum,GLint,GLint,GLint,GLsizei,GLsizei,GLenum,GLenum,const void*
void|glUniform1f|GLint,GLfloat
void|glUniform1i|GLint,GLint
void|glUseProgram|GLuint
void|glViewport|GLint,GLint,GLsizei,GLsizei'''
bridges=['#include "platform.h"']
names={'fprintf','SDL_SetError','SDL_PollEvent','SDL_CreateWindowFrom','stderr'}
for line in spec.splitlines():
    ret,name,types=line.split('|'); names.add(name)
    args=types.split(',') if types else []
    params=', '.join(f'{t} a{i}' for i,t in enumerate(args)) or 'void'
    passed=', '.join(f'a{i}' for i in range(len(args)))
    invoke=f'{name}({passed})'
    if name.startswith('gl'):
        ptype=f'{ret} (APIENTRY *)({types or "void"})'
        bridges.append(f'typedef {ret} (APIENTRY *type_{name})({types or "void"});\nstatic type_{name} ptr_{name};')
        invoke=f'ptr_{name}({passed})'
    body=f'{"return " if ret!="void" else ""}{invoke};'
    bridges.append(f'{ret} SYSV bridge_{name}({params}) {{ {body} }}')
bridges.append('int load_gl(void) {')
for name in sorted(n for n in names if n.startswith('gl')):
    bridges.append(f' ptr_{name}=(type_{name})SDL_GL_GetProcAddress("{name}"); if (!ptr_{name}) return SDL_SetError("Missing OpenGL entry point: {name}");')
bridges.append('return 0; }')
(out/'bridges.c').write_text('\n'.join(bridges)+'\n')
for p in (root/'src').glob('*.asm'):
    s=p.read_text().replace(' wrt ..plt','').replace('section .rodata','section .rdata')
    s=re.sub(r'section \.note\.GNU-stack[^\n]*','',s)
    if p.name=='main.asm':
        s=re.sub(r'\bmain\b','nasm_main',s)
        s=s.replace('db `x11`,0','db `windows`,0').replace('db "x11",0','db "windows",0')
        s=s.replace('    mov rdx,rax\n    shr rdx,32\n    jnz .invalid\n','')
    if p.name=='gpu.asm':
        s=re.sub(r'^extern egl\w+\n','',s,flags=re.M)
        s=re.sub(r'gpu_headless:.*?; Compile one stage', 'gpu_headless:\n    jmp bridge_headless\n\n; Compile one stage',s,flags=re.S)
        s=re.sub(r'\.Legl_cleanup:.*?\.Lshutdown_done:', '.Legl_cleanup:\n.Lshutdown_done:',s,flags=re.S)
        s='extern bridge_headless, bridge_load_gl\n'+s
        s=s.replace('    call gpu_common\n','    call bridge_load_gl\n    test eax,eax\n    js .Linit_fail\n    call gpu_common\n')
    for name in sorted(names,key=len,reverse=True):
        s=re.sub(r'\b'+name+r'\b','bridge_'+name,s)
    (out/p.name).write_text(s)
print('Prepared shared NASM sources and Windows ABI bridges.')
