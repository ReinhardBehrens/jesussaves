#!/usr/bin/env python3
"""Native Windows tests of ABI, 4K renderers and Windows screensaver contract."""
import os, subprocess, tempfile, ctypes, time, sys, traceback
from pathlib import Path
from PIL import Image, ImageChops
def report_exception(kind, value, tb):
    message=''.join(traceback.format_exception(kind,value,tb)).replace('%','%25').replace('\r','%0D').replace('\n','%0A')
    print('::error::'+message,flush=True)
    sys.__excepthook__(kind,value,tb)
sys.excepthook=report_exception
root=Path(__file__).resolve().parents[1]
exe=root/'build/windows/JesusSaves.exe';scr=exe.with_suffix('.scr')
def run(args,**kw):
    return subprocess.run([str(exe),*args],capture_output=True,timeout=120,**kw)
for args in [['--help'],['--bad'],['/p','0'],['/p','garbage'],['/unknown']]:
    p=run(args);assert p.returncode==(0 if args==['--help'] else 2),(args,p.returncode,p.stderr)
for backend in ['cpu','gpu']:
    frames=[]
    with tempfile.TemporaryDirectory() as folder:
        for flag,t in [('--background',0),('--snapshot',0),('--snapshot',9),('--snapshot',0)]:
            p=run(['--'+backend,flag],cwd=folder,env=dict(os.environ,FLAME_TIME=str(t)))
            assert p.returncode==0,(backend,t,p.returncode,p.stderr)
            im=Image.open(Path(folder)/'flame.ppm').convert('RGB');assert im.size==(3840,2160)
            frames.append(im)
        assert frames[1].tobytes()==frames[3].tobytes(),backend
        assert frames[1].tobytes()!=frames[2].tobytes(),backend
        for im in frames[1:3]:
            box=ImageChops.difference(im,frames[0]).crop((0,0,3840,1200)).getbbox()
            assert box and 0<box[0]<box[2]<3840,(backend,box)
            assert len(im.crop((0,1500,3840,2160)).getcolors(1000000) or [])>100
    p=run(['--'+backend,'--windowed'],env=dict(os.environ,FLAME_FRAMES='3'));assert p.returncode==0,(backend,p.stderr)
    print('PASS Windows',backend,': 4K background, animated text/fire, deterministic snapshot, live window')
# The configuration dialog must open and close through its real Cancel button.
u=ctypes.windll.user32
u.FindWindowW.restype=ctypes.c_void_p
u.SendMessageW.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_size_t,ctypes.c_ssize_t]
p=subprocess.Popen([str(scr),'/c'])
try:
    for _ in range(100):
        hwnd=u.FindWindowW(None,'Jesus Saves - Screensaver Settings')
        if hwnd:break
        time.sleep(.1)
    assert hwnd,'Settings dialog missing'
    u.SendMessageW(hwnd,0x111,2,0)
    assert p.wait(timeout=10)==0
finally:
    if p.poll() is None:p.kill()
# Preview receives a real HWND and must not destroy the host window.
u.CreateWindowExW.restype=ctypes.c_void_p
u.CreateWindowExW.argtypes=[ctypes.c_ulong,ctypes.c_wchar_p,ctypes.c_wchar_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p]
u.IsWindow.argtypes=[ctypes.c_void_p];u.DestroyWindow.argtypes=[ctypes.c_void_p]
host=u.CreateWindowExW(0,'STATIC','Jesus Saves test host',0x10000000,0,0,640,360,None,None,None,None)
assert host
try:
    for args in [['/p',str(host)],['/p:'+str(host)]]:
        p=subprocess.run([str(scr),*args],env=dict(os.environ,FLAME_FRAMES='3'),timeout=60,capture_output=True)
        assert p.returncode==0,(args,p.returncode,p.stderr)
        assert u.IsWindow(host),'Preview destroyed host window'
finally:u.DestroyWindow(host)
print('PASS Windows settings and preview HWND embedding')

# Fullscreen saver mode runs with the same renderer and dismisses on input.
p=subprocess.Popen([str(scr),'/s'],env=dict(os.environ,FLAME_FRAMES='3'))
assert p.wait(timeout=60)==0
p=subprocess.Popen([str(scr),'/s'])
try:
    time.sleep(3)
    assert p.poll() is None,'Saver exited before input'
    u.keybd_event(0x1B,0,0,0)
    time.sleep(.15)
    u.keybd_event(0x1B,0,2,0)
    assert p.wait(timeout=30)==0
finally:
    if p.poll() is None:p.kill()
print('PASS Windows fullscreen screensaver and input dismissal')
