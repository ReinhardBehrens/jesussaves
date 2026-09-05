#!/usr/bin/env python3
"""Exercise XScreenSaver-style foreign-window embedding on an actual X11 window."""
import ctypes as C, os, subprocess
from pathlib import Path
sdl=C.CDLL('libSDL2-2.0.so.0')
sdl.SDL_Init.argtypes=[C.c_uint];sdl.SDL_Init.restype=C.c_int
sdl.SDL_CreateWindow.argtypes=[C.c_char_p,C.c_int,C.c_int,C.c_int,C.c_int,C.c_uint];sdl.SDL_CreateWindow.restype=C.c_void_p
sdl.SDL_GetWindowWMInfo.argtypes=[C.c_void_p,C.c_void_p];sdl.SDL_GetWindowWMInfo.restype=C.c_int
sdl.SDL_DestroyWindow.argtypes=[C.c_void_p]
sdl.SDL_GetWindowFlags.argtypes=[C.c_void_p];sdl.SDL_GetWindowFlags.restype=C.c_uint
sdl.SDL_GetError.restype=C.c_char_p
os.environ['SDL_VIDEODRIVER']='x11'
assert sdl.SDL_Init(0x20)==0,sdl.SDL_GetError()
win=sdl.SDL_CreateWindow(b'JESUS SAVES embedding test',100,100,640,360,2)
assert win,sdl.SDL_GetError()
try:
    info=C.create_string_buffer(256);sdl.SDL_GetVersion(info)
    assert sdl.SDL_GetWindowWMInfo(win,info)==1,sdl.SDL_GetError()
    xid=C.c_ulong.from_buffer(info,16).value
    binary=str(Path('build/jesussaves').resolve())
    for mode in ['--gpu','--cpu']:
        env=dict(os.environ,XSCREENSAVER_WINDOW=hex(xid),FLAME_FRAMES='4')
        subprocess.run([binary,mode,'--screensaver'],env=env,check=True,timeout=30)
        assert sdl.SDL_GetWindowFlags(win)!=0, 'Child destroyed host window'
    env=dict(os.environ,FLAME_FRAMES='4');env.pop('XSCREENSAVER_WINDOW',None)
    subprocess.run([binary,'--gpu','--window-id',hex(xid)],env=env,check=True,timeout=30)
    print('PASS: GPU/CPU XScreenSaver embedding; explicit XID; parent window survives.')
finally:
    sdl.SDL_DestroyWindow(win);sdl.SDL_Quit()
