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
    kwargs.setdefault('timeout', 30)
    print('::notice::Checking ' + ' '.join(str(x) for x in args), flush=True)
    timeout = kwargs.pop('timeout')
    proc = subprocess.Popen([str(x) for x in args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kwargs)
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        report = Path(tempfile.gettempdir()) / ('jesussaves-sample-' + str(proc.pid) + '.txt')
        subprocess.run(['sample', str(proc.pid), '1', '1', '-file', str(report)], capture_output=True, timeout=15)
        proc.kill()
        stdout, stderr = proc.communicate()
        message = 'Timed out running ' + ' '.join(str(x) for x in args) + '\n' + stderr
        if report.exists(): message += '\n' + report.read_text()[:10000]
        print('::error::' + message.replace('%','%25').replace('\r','%0D').replace('\n','%0A'), flush=True)
        raise RuntimeError('Process timed out')
    result = subprocess.CompletedProcess(args, proc.returncode, stdout, stderr)
    if result.returncode:
        message=(result.stdout+result.stderr).replace('%','%25').replace('\r','%0D').replace('\n','%0A')
        print('::error::'+message)
        raise RuntimeError(f'Command failed: {args}')
    return result.stdout
arch=platform.machine()
assert arch in run(['lipo','-archs',exe])
run(['codesign','--verify','--deep','--strict',app])
run([exe,'--help'])
backends=['--cpu','--gpu'] if arch=='x86_64' else ['--gpu']
for backend in backends:
    images=[]
    for t in (0,2):
        with tempfile.TemporaryDirectory() as d:
            run([exe,backend,'--snapshot'],cwd=d,env=dict(os.environ,FLAME_TIME=str(t)),timeout=180)
            im=Image.open(Path(d)/'flame.ppm').convert('RGB')
            assert im.size==(3840,2160)
            assert len(im.resize((384,216)).getcolors(100000) or [])>100
            images.append(im)
    assert ImageChops.difference(*images).getbbox(), 'Animation is static'
run([exe,'--windowed'],env=dict(os.environ,FLAME_FRAMES='3'),timeout=180)
print(f'PASS packaged {arch}: 4K {backends} rendering, animation, live GPU window, signature and bundled dependencies.')
