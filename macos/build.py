#!/usr/bin/env python3
"""Build the Intel macOS application on macOS with NASM and SDL2 installed."""
import os
from pathlib import Path
import platform
import plistlib
import shlex
import shutil
import subprocess
root = Path(__file__).resolve().parents[1]
os.chdir(root)
def run(args):
    result = subprocess.run([str(a) for a in args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end='')
    if result.returncode:
        if os.environ.get('GITHUB_ACTIONS'):
            message = result.stdout[-12000:].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
            print('::error::' + message)
        raise subprocess.CalledProcessError(result.returncode, args)
if platform.system() != 'Darwin' or platform.machine() != 'x86_64':
    raise SystemExit('Run on an Intel macOS host (or x86_64 Rosetta shell with Intel SDL2).')
run(['python3', 'scripts/pack_background.py'])
run(['python3', 'macos/prepare.py'])
out = root / 'build/macos'
objects = []
for source in sorted(out.glob('*.asm')):
    obj = source.with_suffix('.o')
    run(['nasm', '-f', 'macho64', '-o', obj, source])
    objects.append(obj)
sdl_flags = shlex.split(subprocess.check_output(['sdl2-config', '--cflags', '--libs'], text=True))
run(['clang', '-arch', 'x86_64', '-mmacosx-version-min=12.0', '-Wl,-no_pie',
     '-O2', '-Wall', '-Wextra', '-o', out / 'jesussaves', *objects,
     'macos/platform.c', *sdl_flags, '-framework', 'OpenGL'])
app = out / 'Jesus Saves.app'
contents = app / 'Contents'
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
(contents / 'Frameworks').mkdir(exist_ok=True)
shutil.copy2(out / 'jesussaves', contents / 'MacOS/jesussaves')
# Bundle the SDL dylib rather than requiring Homebrew on the user's Mac.
exe = contents / 'MacOS/jesussaves'
deps = subprocess.check_output(['otool', '-L', exe], text=True)
sdl = next(line.strip().split(' (')[0] for line in deps.splitlines()[1:] if 'libSDL2' in line)
bundled = contents / 'Frameworks/libSDL2.dylib'
shutil.copy2(sdl, bundled)
run(['install_name_tool', '-id', '@executable_path/../Frameworks/libSDL2.dylib', bundled])
run(['install_name_tool', '-change', sdl, '@executable_path/../Frameworks/libSDL2.dylib', exe])
with (contents / 'Info.plist').open('wb') as f:
    plistlib.dump(dict(CFBundleExecutable='jesussaves', CFBundleIdentifier='org.jesussaves.app',
                      CFBundleName='Jesus Saves', CFBundlePackageType='APPL',
                      CFBundleVersion=(root / 'VERSION').read_text().strip(),
                      LSMinimumSystemVersion='12.0', NSHighResolutionCapable=True), f)
shutil.copy2(root / 'LICENSE', contents / 'LICENSE')
shutil.copytree(root / 'licenses', contents / 'licenses', dirs_exist_ok=True)
shutil.copy2(root / 'macos/README.md', contents / 'README.md')
run(['codesign', '--force', '--deep', '--sign', '-', app])
(root / 'dist').mkdir(exist_ok=True)
run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app,
     root / 'dist/jesussaves-macos-intel.zip'])
