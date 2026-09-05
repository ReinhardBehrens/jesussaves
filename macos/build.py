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
if platform.system() != 'Darwin':
    raise SystemExit('Run this build on macOS.')
arch = platform.machine()
if arch not in ('x86_64', 'arm64'):
    raise SystemExit('Unsupported Mac architecture: ' + arch)
label = 'intel' if arch == 'x86_64' else 'arm64'
run(['python3', 'scripts/pack_background.py'])
out = root / 'build/macos'
out.mkdir(parents=True, exist_ok=True)
objects = []
if arch == 'x86_64':
    run(['python3', 'macos/prepare.py'])
    for source in sorted(out.glob('*.asm')):
        obj = source.with_suffix('.o')
        run(['nasm', '-f', 'macho64', '-o', obj, source])
        objects.append(obj)
sdl_flags = shlex.split(subprocess.check_output(['sdl2-config', '--cflags', '--libs'], text=True))
source = 'macos/platform.c' if arch == 'x86_64' else 'macos/arm64.c'
link_flags = ['-Wl,-no_pie'] if arch == 'x86_64' else []
run(['clang', '-arch', arch, '-mmacosx-version-min=14.0', *link_flags,
     '-O2', '-ffp-contract=off', '-Wall', '-Wextra', '-o', out / 'jesussaves', *objects,
     source, *sdl_flags, '-framework', 'OpenGL'])
app = out / 'Jesus Saves.app'
contents = app / 'Contents'
if app.exists():
    shutil.rmtree(app)
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
(contents / 'Frameworks').mkdir(exist_ok=True)
shutil.copy2(out / 'jesussaves', contents / 'MacOS/jesussaves')
if arch == 'arm64':
    resources = contents / 'Resources'
    resources.mkdir()
    for source in ['build/background.bgra', 'assets/text-sdf.bin', 'assets/turbulence.bin',
                   'shaders/scene.vert', 'shaders/scene.frag']:
        shutil.copy2(root / source, resources / Path(source).name)
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
                      LSMinimumSystemVersion='14.0', NSHighResolutionCapable=True), f)
shutil.copy2(root / 'LICENSE', contents / 'LICENSE')
shutil.copytree(root / 'licenses', contents / 'licenses', dirs_exist_ok=True)
shutil.copy2(root / 'macos/README.md', contents / 'README.md')
shutil.copy2(root / 'macos/install-rosetta.command', contents / 'install-rosetta.command')
run(['codesign', '--force', '--deep', '--sign', '-', app])
(root / 'dist').mkdir(exist_ok=True)
run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app,
     root / f'dist/jesussaves-macos-{label}.zip'])
