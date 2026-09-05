#!/usr/bin/env python3
"""Cross-build with MinGW-w64 and NASM; SDL_ROOT is the official MinGW SDK."""
import os,shlex,subprocess,shutil,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];os.chdir(root)
def run(args): subprocess.run([str(a) for a in args],check=True)
run([os.environ.get('PYTHON','python3'),'scripts/pack_background.py'])
run([os.environ.get('PYTHON','python3'),'windows/prepare.py'])
out=root/'build/windows';sdl=Path(os.environ['SDL_ROOT']).resolve()
cc=os.environ.get('WIN_CC','x86_64-w64-mingw32-gcc')
windres=os.environ.get('WINDRES','x86_64-w64-mingw32-windres')
flags=shlex.split(os.environ.get('WIN_CFLAGS',''))
objects=[]
for source in sorted(out.glob('*.asm')):
    obj=source.with_suffix('.o');run([os.environ.get('NASM','nasm'),'-f','win64','-o',obj,source]);objects.append(obj)
for source in [out/'bridges.c',root/'windows/platform.c']:
    obj=out/(source.stem+'.o')
    run([cc,*flags,'-O2','-fno-omit-frame-pointer','-Wall','-Wextra','-Werror','-mno-red-zone','-maccumulate-outgoing-args','-Iwindows','-I'+str(sdl/'include/SDL2'),'-c',source,'-o',obj]);objects.append(obj)
run([windres,'--preprocessor='+cc,'--preprocessor-arg=-E','--preprocessor-arg=-xc','--preprocessor-arg=-DRC_INVOKED',*[f for f in flags if f.startswith('-I')],'-i','windows/settings.rc','-o',out/'settings.o']);objects.append(out/'settings.o')
run([cc,*flags,'-static-libgcc','-mwindows','-o',out/'JesusSaves.exe',*objects,'-L'+str(sdl/'lib'),'-lSDL2','-luser32','-ladvapi32','-lgdi32','-lm'])
shutil.copy2(out/'JesusSaves.exe',out/'JesusSaves.scr')
shutil.copy2(sdl/'bin/SDL2.dll',out/'SDL2.dll')
print('Built Windows x64 executable and screensaver.')
