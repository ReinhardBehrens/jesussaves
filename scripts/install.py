#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Per-user installation; idle activation remains an explicit user choice."""
import argparse,shutil
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--prefix',type=Path,default=Path.home()/'.local')
p.add_argument('--uninstall',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1]
files={'build/jesussaves':'bin/jesussaves','scripts/idle.py':'share/jesussaves/idle.py','scripts/register_xscreensaver.py':'bin/jesussaves-register','packaging/jesussaves.desktop':'share/applications/jesussaves.desktop','packaging/jesussaves.xml':'share/xscreensaver/config/jesussaves.xml','packaging/jesussaves-idle.service':'share/systemd/user/jesussaves-idle.service'}
for src,dst in files.items():
    target=a.prefix/dst
    if a.uninstall:target.unlink(missing_ok=True);continue
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/src,target)
    if dst.startswith('bin/') or dst.endswith('.py'):target.chmod(0o755)
    if dst.endswith('.service'):
        s=target.read_text().replace('/usr/share/jesussaves',str(a.prefix/'share/jesussaves'))
        s=s.replace('Environment=JESUSSAVES_IDLE_SECONDS',f'Environment=JESUSSAVES_BINARY={a.prefix}/bin/jesussaves\nEnvironment=JESUSSAVES_IDLE_SECONDS')
        target.write_text(s)
print('Removed user installation.' if a.uninstall else f'Installed under {a.prefix}. See README for optional idle/XScreenSaver activation.')
