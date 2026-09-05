#!/usr/bin/env python3
"""Exercise the shipped installer against a real, disposable Windows CI account."""
import ctypes, json, os, subprocess, sys, tempfile, time, traceback, winreg, zipfile
from pathlib import Path

def report_exception(kind, value, tb):
    message=''.join(traceback.format_exception(kind,value,tb)).replace('%','%25').replace('\r','%0D').replace('\n','%0A')
    print('::error::'+message,flush=True)
    sys.__excepthook__(kind,value,tb)
sys.excepthook=report_exception
root=Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text().strip()
u=ctypes.windll.user32
u.SystemParametersInfoW.argtypes=[ctypes.c_uint,ctypes.c_uint,ctypes.c_void_p,ctypes.c_uint]
def get_spi(action):
    value=ctypes.c_uint()
    assert u.SystemParametersInfoW(action,0,ctypes.byref(value),0)
    return value.value
key=winreg.OpenKey(winreg.HKEY_CURRENT_USER,r'Control Panel\Desktop',0,winreg.KEY_READ|winreg.KEY_SET_VALUE)
names=['SCRNSAVE.EXE','ScreenSaveActive','ScreenSaveTimeOut','ScreenSaverIsSecure']
def read(name):
    try:return winreg.QueryValueEx(key,name)
    except FileNotFoundError:return None
old={n:read(n) for n in names};old_active=get_spi(0x10);old_timeout=get_spi(0x0E)
try:
    with tempfile.TemporaryDirectory(prefix='Jesus Saves installer ') as folder:
        dest=Path(folder)
        with zipfile.ZipFile(root/f'dist/jesussaves-{version}-windows-x64.zip') as z:z.extractall(dest/'download')
        script=dest/'download/JesusSaves/install.ps1'
        env=dict(os.environ,LOCALAPPDATA=str(dest/'user data'))
        installed=dest/'user data/JesusSaves'
        def install(path,minutes=None):
            args=['powershell.exe','-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',str(path),'-NoSettings']
            if minutes is not None:args+=['-Minutes',str(minutes)]
            p=subprocess.run(args,env=env,capture_output=True,timeout=60)
            assert p.returncode==0,(p.stdout,p.stderr)
        # Reproduce the reported state: no selected screensaver, disabled, zero wait.
        try:winreg.DeleteValue(key,'SCRNSAVE.EXE')
        except FileNotFoundError:pass
        assert u.SystemParametersInfoW(0x11,0,None,3)
        assert u.SystemParametersInfoW(0x0F,0,None,3)
        install(script)
        assert read('SCRNSAVE.EXE')[0]==str(installed/'JesusSaves.scr')
        assert get_spi(0x10)==1 and get_spi(0x0E)==300
        assert read('ScreenSaveActive')[0]=='1' and read('ScreenSaveTimeOut')[0]=='300'
        assert read('ScreenSaverIsSecure')==old['ScreenSaverIsSecure']
        assert (installed/'SDL2.dll').is_file() and (installed/'licenses/DejaVu.txt').is_file()
        backup=(installed/'previous-screensaver.json').read_bytes()
        # Reinstall from the installed folder; custom time and initial backup survive.
        install(installed/'install.ps1',7)
        assert get_spi(0x0E)==420 and get_spi(0x10)==1
        assert (installed/'previous-screensaver.json').read_bytes()==backup
        assert read('ScreenSaverIsSecure')==old['ScreenSaverIsSecure']
        # Check what the same settings panel actually displays to the user.
        u.FindWindowW.restype=ctypes.c_void_p
        u.FindWindowW.argtypes=[ctypes.c_wchar_p,ctypes.c_wchar_p]
        u.SendMessageW.restype=ctypes.c_ssize_t
        u.SendMessageW.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_size_t,ctypes.c_void_p]
        callback_type=ctypes.WINFUNCTYPE(ctypes.c_bool,ctypes.c_void_p,ctypes.c_ssize_t)
        u.EnumChildWindows.argtypes=[ctypes.c_void_p,callback_type,ctypes.c_ssize_t]
        u.GetClassNameW.argtypes=[ctypes.c_void_p,ctypes.c_wchar_p,ctypes.c_int]
        panel=subprocess.Popen(['rundll32.exe','shell32.dll,Control_RunDLL','desk.cpl,,1'])
        hwnd=None
        try:
            for _ in range(100):
                hwnd=u.FindWindowW(None,'Screen Saver Settings')
                if hwnd:break
                time.sleep(.1)
            assert hwnd,'Screen Saver Settings did not open'
            selections=[]; edits=[]
            @callback_type
            def collect(child,_):
                cls=ctypes.create_unicode_buffer(128);u.GetClassNameW(child,cls,128)
                if cls.value=='ComboBox':
                    selected=u.SendMessageW(child,0x147,0,None)
                    if selected>=0:
                        length=u.SendMessageW(child,0x149,selected,None)
                        if 0<=length<1024:
                            text=ctypes.create_unicode_buffer(length+1)
                            u.SendMessageW(child,0x148,selected,ctypes.cast(text,ctypes.c_void_p))
                            selections.append(text.value)
                if cls.value=='Edit':
                    text=ctypes.create_unicode_buffer(128)
                    u.SendMessageW(child,0xD,128,ctypes.cast(text,ctypes.c_void_p));edits.append(text.value)
                return True
            u.EnumChildWindows(hwnd,collect,0)
            assert any('jesus' in text.lower() for text in selections),selections
            assert '7' in edits,edits
            print('PASS Windows settings panel: selected Jesus Saves and displayed 7-minute custom wait')
        finally:
            if hwnd:u.SendMessageW(hwnd,0x111,2,None)
            try:panel.wait(timeout=10)
            except subprocess.TimeoutExpired:panel.kill()
        print('PASS installer: selects Jesus Saves, enables saver, defaults to 5 minutes, supports reinstall/custom time, preserves sign-in setting')
finally:
    assert u.SystemParametersInfoW(0x0F,old_timeout,None,3)
    assert u.SystemParametersInfoW(0x11,old_active,None,3)
    for name,value in old.items():
        if value is None:
            try:winreg.DeleteValue(key,name)
            except FileNotFoundError:pass
        else:winreg.SetValueEx(key,name,0,value[1],value[0])
    key.Close()
