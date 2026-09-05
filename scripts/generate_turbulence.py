#!/usr/bin/env python3
"""Build a seamless multiscale turbulence field; embedded by the assembler."""
from pathlib import Path
from PIL import Image
import random,struct
rng=random.Random(730214)
W,H=512,256
field=[0.0]*(W*H)
for gw,gh,weight in [(8,4,.45),(16,8,.27),(32,16,.16),(64,32,.08),(128,64,.04)]:
    tile=Image.frombytes('L',(gw,gh),bytes(rng.randrange(256) for _ in range(gw*gh)))
    wrap=Image.new('L',(gw*3,gh*3))
    for y in range(3):
        for x in range(3): wrap.paste(tile,(x*gw,y*gh))
    layer=wrap.resize((W*3,H*3),Image.Resampling.BICUBIC).crop((W,H,2*W,2*H))
    for i,v in enumerate(layer.tobytes()): field[i]+=(v/127.5-1)*weight
mean=sum(field)/len(field)
field=[max(-1,min(1,(v-mean)*1.8)) for v in field]
(Path(__file__).resolve().parents[1]/'assets/turbulence.bin').write_bytes(struct.pack('<%df'%len(field),*field))
print('Generated seamless turbulence at five spatial scales.')
