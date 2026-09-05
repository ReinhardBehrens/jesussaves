#!/usr/bin/env python3
"""Optional build-time font -> distance field. No Python used by the executable."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math, struct
W,H=1536,256
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',176)
mask=Image.new('L',(W,H)); draw=ImageDraw.Draw(mask)
b=draw.textbbox((0,0),'JESUS SAVES',font=font)
draw.text(((W-b[2]+b[0])/2-b[0],(H-b[3]+b[1])/2-b[1]),'JESUS SAVES',font=font,fill=255)
inside=[v>=128 for v in mask.tobytes()]
def distance(target):
    d=[0.0 if p==target else 1e6 for p in inside]
    for indices,dirs in [(range(W*H),[(-1,0),(0,-1),(-1,-1),(1,-1)]),(range(W*H-1,-1,-1),[(1,0),(0,1),(1,1),(-1,1)])]:
        for i in indices:
            x,y=i%W,i//W
            for dx,dy in dirs:
                if 0<=x+dx<W and 0<=y+dy<H:
                    d[i]=min(d[i],d[i+dy*W+dx]+(math.sqrt(2) if dx and dy else 1))
    return d
to_inside,to_outside=distance(True),distance(False)
sdf=[-(to_outside[i]-.5) if p else to_inside[i]-.5 for i,p in enumerate(inside)]
(Path(__file__).resolve().parents[1]/'assets/text-sdf.bin').write_bytes(struct.pack('<%df'%len(sdf),*(v/4 for v in sdf)))
print('Generated 1536 x 256 signed-distance lettering.')
