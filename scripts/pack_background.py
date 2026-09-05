#!/usr/bin/env python3
"""Encode the checked-in 4K PNG as raw BGRA for NASM INCBIN; no rescaling."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
im=Image.open(root/'assets/heaven-4k.png').convert('RGBA')
assert im.size==(3840,2160), 'Background must be 4K UHD'
(root/'build').mkdir(exist_ok=True)
(root/'build/background.bgra').write_bytes(im.tobytes('raw','BGRA'))
