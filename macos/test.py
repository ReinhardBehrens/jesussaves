#!/usr/bin/env python3
"""Test the packaged app (including dylib/assets resolution) on its native Mac."""
import os
from pathlib import Path
import platform
import subprocess
import tempfile
from PIL import Image, ImageChops
root=Path(__file__).resolve().parents[1]
app=root/'build/macos/Jesus Saves.app'
exe=app/'Contents/MacOS/jesussaves'
def run(args, **kwargs):
    result=subprocess.run([str(x) for x in args],capture_output=True,text=True,**kwargs)
    if result.returncode:
        message=(result.stdout+result.stderr).replace('%','%25').replace('\r','%0D').replace('\n','%0A')
        print('::error::'+message)
        raise RuntimeError(f'Command failed: {args}')
    return result.stdout
arch=platform.machine()
assert arch in run(['lipo','-archs',exe])
run(['codesign','--verify','--deep','--strict',app])
run([exe,'--help'])
backend='--cpu' if arch=='x86_64' else '--gpu'
images=[]
for t in (0,2):
    with tempfile.TemporaryDirectory() as d:
        run([exe,backend,'--snapshot'],cwd=d,env=dict(os.environ,FLAME_TIME=str(t)),timeout=180)
        im=Image.open(Path(d)/'flame.ppm').convert('RGB')
        assert im.size==(3840,2160)
        assert len(im.resize((384,216)).getcolors(100000) or [])>100
        images.append(im)
assert ImageChops.difference(*images).getbbox(), 'Animation is static'
print(f'PASS packaged {arch}: 4K {backend} rendering, animation, signature and bundled dependencies.')
