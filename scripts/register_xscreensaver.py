#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-only
"""Register one saver without changing existing locking/timeout settings."""
import argparse,re,shutil
from pathlib import Path

def register(path,binary):
    if any(c in str(binary) for c in '\n\r"\\'):raise ValueError('Unsupported character in binary path')
    old=path.read_text() if path.exists() else ''
    if re.search(r'GL: "Jesus Saves 4K"',old):return False
    if path.exists():
        backup=path.with_name(path.name+'.jesussaves.bak')
        if not backup.exists():shutil.copy2(path,backup)
    entry=f'\tGL: "Jesus Saves 4K" "{binary}" --screensaver'
    m=re.search(r'^programs:[ \t]*',old,re.M)
    if m:
        tail=old[m.end():]
        if tail.startswith('\\\n'):tail=tail[2:]
        new=old[:m.start()]+'programs: \\\n'+entry+' \\n\\\n'+tail
        new=re.sub(r'^(selected:[ \t]*)(\d+)',lambda match:match[1]+str(int(match[2])+1),new,flags=re.M)
    else:new=old.rstrip()+'\n\nprograms: \\\n'+entry+'\n'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(new)
    return True

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,default=Path.home()/'.xscreensaver')
    parser.add_argument('--binary',type=Path,default=Path('/usr/bin/jesussaves'))
    args=parser.parse_args()
    if not args.binary.is_file():parser.error('Install/build the binary first')
    changed=register(args.config,args.binary.resolve())
    print('Registered Jesus Saves 4K. Open xscreensaver-settings to select it.' if changed else 'Already registered.')
if __name__=='__main__':main()
