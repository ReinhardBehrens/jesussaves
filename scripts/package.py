#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build an amd64 Debian package without root or system modifications."""
from pathlib import Path
import shutil,subprocess
ROOT=Path(__file__).resolve().parents[1];stage=ROOT/'build/package-root';out=ROOT/'dist'
version=(ROOT/'VERSION').read_text().strip()
if not (ROOT/'build/jesussaves').exists():raise SystemExit('Run make first')
if stage.exists():shutil.rmtree(stage)
stage.mkdir(parents=True);out.mkdir(exist_ok=True)
files={'build/jesussaves':'usr/bin/jesussaves','scripts/idle.py':'usr/share/jesussaves/idle.py','scripts/register_xscreensaver.py':'usr/bin/jesussaves-register','packaging/jesussaves.desktop':'usr/share/applications/jesussaves.desktop','packaging/jesussaves.xml':'usr/share/xscreensaver/config/jesussaves.xml','packaging/jesussaves-idle.service':'usr/lib/systemd/user/jesussaves-idle.service','README.md':'usr/share/doc/jesussaves/README.md','LICENSE':'usr/share/doc/jesussaves/copyright','licenses/DejaVu.txt':'usr/share/doc/jesussaves/DejaVu.txt','docs/ARCHITECTURE.md':'usr/share/doc/jesussaves/ARCHITECTURE.md','docs/ASSETS.md':'usr/share/doc/jesussaves/ASSETS.md'}
for src,dst in files.items():
    target=stage/dst;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/src,target)
    target.chmod(0o755 if dst.startswith('usr/bin/') or dst.endswith('.py') else 0o644)
subprocess.run(['strip','--strip-unneeded',str(stage/'usr/bin/jesussaves')],check=True)
# XScreenSaver includes this directory in its module search path.
link=stage/'usr/lib/xscreensaver/jesussaves';link.parent.mkdir(parents=True,exist_ok=True);link.symlink_to('../../bin/jesussaves')
size=sum(p.stat().st_size for p in stage.rglob('*') if p.is_file() and not p.is_symlink())//1024
control=stage/'DEBIAN';control.mkdir()
(control/'control').write_text(f'''Package: jesussaves
Version: {version}
Section: x11
Priority: optional
Architecture: amd64
Maintainer: Jesus Saves contributors <noreply@github.com>
Depends: libc6 (>= 2.34), libsdl2-2.0-0 (>= 2.0.12), libgl1, libegl1, python3, python3-gi
Recommends: xscreensaver
Installed-Size: {size}
Homepage: https://github.com/ReinhardBehrens/jesussaves
Description: 4K gold text and flame screensaver with NASM CPU and GPU backends
 Reflective 3D JESUS SAVES lettering above turbulent flames and a heavenly
 background. Includes GNOME idle integration and XScreenSaver embedding.
 Rendering uses NASM/SSE2 or NASM-controlled OpenGL 3.3 with GLSL effects.
''')
package=out/f'jesussaves_{version}_amd64.deb'
subprocess.run(['dpkg-deb','--root-owner-group','-Zxz','--build',str(stage),str(package)],check=True)
print(package)
