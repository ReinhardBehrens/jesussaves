#!/usr/bin/env python3
from pathlib import Path
import zipfile, hashlib
root=Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text().strip()
dist=root/'dist';dist.mkdir(exist_ok=True)
archive=dist/f'jesussaves-{version}-windows-x64.zip'
files={f'build/windows/{n}':n for n in ['JesusSaves.exe','JesusSaves.scr','SDL2.dll']}
files.update({'LICENSE':'LICENSE','licenses/DejaVu.txt':'licenses/DejaVu.txt','windows/README-Windows.md':'README-Windows.md','windows/install.cmd':'install.cmd','licenses/SDL2.txt':'SDL2-LICENSE.txt'})
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for src,dst in files.items():z.write(root/src,'JesusSaves/'+dst)
archive.with_suffix('.zip.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
print(archive)
