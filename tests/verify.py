#!/usr/bin/env python3
"""4K render, backend, animation, and argument regressions; no desktop required."""
import os,subprocess,tempfile
from pathlib import Path
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1];BINARY=ROOT/'build/jesussaves'

def snapshot(backend,t,background=False):
    with tempfile.TemporaryDirectory() as d:
        env=dict(os.environ,FLAME_TIME=str(t));env.pop('XSCREENSAVER_WINDOW',None)
        subprocess.run([str(BINARY),'--'+backend,'--background' if background else '--snapshot'],cwd=d,env=env,check=True,stdout=subprocess.DEVNULL,timeout=60)
        return Image.open(Path(d)/'flame.ppm').convert('RGB')

for backend in ['cpu','gpu']:
    bg=snapshot(backend,0,True);assert bg.size==(3840,2160)
    boxes=[];bottoms=[]
    for t in [0,2,4,6,9,13,20,30]:
        im=snapshot(backend,t);assert im.size==(3840,2160)
        diff=ImageChops.difference(im,bg).crop((0,0,3840,1200)).convert('L').point(lambda v:255 if v>15 else 0)
        b=diff.getbbox();assert b and 0<b[0]<b[2]<3840 and 0<b[1]<b[3]<1200,(backend,t,b)
        boxes.append(b)
        fire=im.crop((0,1400,3840,2160));assert len(fire.getcolors(1_000_000) or [])>100
        bottoms.append(fire.tobytes())
    assert max(b[0] for b in boxes)-min(b[0] for b in boxes)>500
    assert max(b[1] for b in boxes)-min(b[1] for b in boxes)>400
    assert max(b[2]-b[0] for b in boxes)-min(b[2]-b[0] for b in boxes)>900
    assert len(set(bottoms))==len(bottoms)
    assert snapshot(backend,0).tobytes()==snapshot(backend,0).tobytes()
    for t in ['nan','inf','-4']:snapshot(backend,t)
    print(f'PASS {backend}: 4K output, gold geometry/drift bounds, variable fire, deterministic snapshots.')
for args in [['--bad'],['--window-id'],['--window-id','garbage'],['--window-id','-1'],['--window-id','0'],['--window-id','0x100000000']]:
    env=dict(os.environ);env.pop('XSCREENSAVER_WINDOW',None)
    assert subprocess.run([str(BINARY),*args],env=env,capture_output=True,timeout=5).returncode==2,args
assert subprocess.run([str(BINARY),'--help'],capture_output=True).returncode==0
print('PASS CLI validation.')
