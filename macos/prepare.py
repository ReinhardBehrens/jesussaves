#!/usr/bin/env python3
"""Adapt shared SysV NASM sources to Mach-O; never change rendering algorithms."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
out = root / 'build/macos'
out.mkdir(parents=True, exist_ok=True)
for source in (root / 'src').glob('*.asm'):
    s = source.read_text().replace(' wrt ..plt', '')
    s = re.sub(r'section \.note\.GNU-stack[^\n]*', '', s)
    s = s.replace('section .rodata', 'section __TEXT,__const')
    s = re.sub(r'\bstderr\b', '__stderrp', s)
    if source.name == 'gpu.asm':
        s = re.sub(r'^extern egl\w+\n', '', s, flags=re.M)
        s = re.sub(r'gpu_headless:.*?; Compile one stage',
                   'gpu_headless:\n    jmp mac_headless\n\n; Compile one stage', s, flags=re.S)
        s = re.sub(r'\.Legl_cleanup:.*?\.Lshutdown_done:',
                   '.Legl_cleanup:\n.Lshutdown_done:', s, flags=re.S)
        s = 'extern mac_headless\n' + s
        # macOS exposes core 3.2 / 4.1, with a forward-compatible context.
        s = s.replace('mov edi,17\n    mov esi,3', 'mov edi,17\n    mov esi,4')
        s = s.replace('mov edi,18\n    mov esi,3', 'mov edi,18\n    mov esi,1')
        s = s.replace('global gpu_configure', 'global gpu_configure')
        s = s.replace('gpu_configure:\n    sub rsp,8',
                      'gpu_configure:\n    sub rsp,8\n    mov edi,20\n    mov esi,2\n    call SDL_GL_SetAttribute')
    # Prefix public C and cross-object symbols; local labels remain unchanged.
    names = set()
    for decl in re.findall(r'^(?:extern|global)\s+([^;\n]+)', s, re.M):
        names.update(n.strip() for n in decl.split(','))
    for name in sorted(names, key=len, reverse=True):
        parts = re.split(r'("[^"\n]*"|`[^`\n]*`)', s)
        s = ''.join(part if i % 2 else re.sub(r'\b' + re.escape(name) + r'\b', '_' + name, part)
                    for i, part in enumerate(parts))
    (out / source.name).write_text(s)
