#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-only
"""GNOME/Wayland idle companion. GNOME retains all screen-locking responsibility."""
import argparse, logging, os, signal, subprocess
from pathlib import Path
import gi
gi.require_version('Gio','2.0')
from gi.repository import Gio, GLib
try:
    from gi.repository import GLibUnix
    add_unix_signal=GLibUnix.signal_add
except (ImportError, AttributeError):  # Older typelibs omit GLibUnix.signal_add
    add_unix_signal=GLib.unix_signal_add

class IdleSaver:
    def __init__(self, binary, backend, seconds):
        self.binary,self.backend,self.seconds=binary,backend,seconds
        self.child=None; self.active_watch=0
        self.idle=self.proxy('org.gnome.Mutter.IdleMonitor','/org/gnome/Mutter/IdleMonitor/Core','org.gnome.Mutter.IdleMonitor')
        self.lock=self.proxy('org.gnome.ScreenSaver','/org/gnome/ScreenSaver','org.gnome.ScreenSaver')
        self.idle.connect('g-signal',self.idle_signal)
        self.lock.connect('g-signal',self.lock_signal)
        self.lock.connect('notify::g-name-owner',lambda *_:self.stop())
        self.idle.connect('notify::g-name-owner',lambda *_:self.stop())
    @staticmethod
    def proxy(name,path,interface):
        p=Gio.DBusProxy.new_for_bus_sync(Gio.BusType.SESSION,Gio.DBusProxyFlags.DO_NOT_AUTO_START,None,name,path,interface,None)
        if not p.get_name_owner(): raise RuntimeError(f'{name} is not available in this session')
        return p
    @staticmethod
    def call(proxy,method,value=None):
        return proxy.call_sync(method,value,Gio.DBusCallFlags.NONE,2000,None).unpack()
    def locked(self):
        try:return self.call(self.lock,'GetActive')[0]
        except GLib.Error:return True
    def start(self):
        if self.locked() or self.child is not None and self.child.poll() is None:return
        # Register the activity watch before opening the window to avoid missing input.
        self.active_watch=self.call(self.idle,'AddUserActiveWatch')[0]
        env=dict(os.environ);env.pop('XSCREENSAVER_WINDOW',None)
        self.child=subprocess.Popen([self.binary,'--'+self.backend],env=env)
        logging.info('Started %s renderer',self.backend)
    def stop(self):
        child,self.child=self.child,None
        if child is not None and child.poll() is None:
            child.terminate()
            try:child.wait(timeout=2)
            except subprocess.TimeoutExpired:child.kill();child.wait()
            logging.info('Stopped renderer')
    def idle_signal(self,_proxy,_sender,name,params):
        if name!='WatchFired':return
        watch=params.unpack()[0]
        if watch==self.active_watch:self.active_watch=0;self.stop()
        elif watch==self.idle_watch:self.start()
    def lock_signal(self,_proxy,_sender,name,params):
        if name=='ActiveChanged' and params.unpack()[0]:self.stop()
    def run(self):
        self.idle_watch=self.call(self.idle,'AddIdleWatch',GLib.Variant('(t)',(self.seconds*1000,)))[0]
        loop=GLib.MainLoop()
        def quit_loop(*_):self.stop();loop.quit();return False
        add_unix_signal(GLib.PRIORITY_DEFAULT,signal.SIGTERM,quit_loop)
        add_unix_signal(GLib.PRIORITY_DEFAULT,signal.SIGINT,quit_loop)
        logging.info('Watching for %s seconds of idle time; GNOME lock remains in control',self.seconds)
        try:loop.run()
        finally:self.stop()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',default=os.environ.get('JESUSSAVES_BINARY','/usr/bin/jesussaves'))
    parser.add_argument('--backend',choices=['cpu','gpu'],default=os.environ.get('JESUSSAVES_BACKEND','gpu'))
    parser.add_argument('--seconds',type=int,default=int(os.environ.get('JESUSSAVES_IDLE_SECONDS','240')))
    parser.add_argument('--check',action='store_true',help='Check session APIs without registering or launching')
    args=parser.parse_args()
    if args.seconds<1:parser.error('--seconds must be positive')
    logging.basicConfig(level=logging.INFO,format='jesussaves-idle: %(message)s')
    saver=IdleSaver(args.binary,args.backend,args.seconds)
    if args.check:
        idle=saver.call(saver.idle,'GetIdletime')[0]
        print(f'GNOME idle API available; idle={idle} ms; locked={saver.locked()}')
    else:
        if not Path(args.binary).is_file():parser.error('Renderer binary was not found')
        saver.run()
if __name__=='__main__':main()
