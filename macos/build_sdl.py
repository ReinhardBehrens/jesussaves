#!/usr/bin/env python3
"""Build pinned upstream SDL2, avoiding SDL2-compat's extra runtime dependency."""
import hashlib
import os
from pathlib import Path
import subprocess
import tarfile
import urllib.request
root=Path(__file__).resolve().parents[1]
version='2.32.10'
prefix=root/'build'/('sdl2-'+version+'-install')
if not (prefix/'bin/sdl2-config').exists():
    archive=root/'build'/('SDL2-'+version+'.tar.gz')
    archive.parent.mkdir(parents=True,exist_ok=True)
    if not archive.exists():
        urllib.request.urlretrieve('https://www.libsdl.org/release/SDL2-'+version+'.tar.gz',archive)
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != '5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165':
        raise SystemExit('SDL2 source checksum mismatch: '+digest)
    source=root/'build'/('SDL2-'+version)
    with tarfile.open(archive) as tar:
        tar.extractall(root/'build',filter='data')
    env=dict(os.environ,MACOSX_DEPLOYMENT_TARGET='14.0')
    subprocess.run([str(source/'configure'),'--prefix='+str(prefix),'--disable-static','--enable-shared'],cwd=source,env=env,check=True)
    subprocess.run(['make','-j4'],cwd=source,env=env,check=True)
    subprocess.run(['make','install'],cwd=source,env=env,check=True)
print('Pinned SDL2 ready:',prefix)
