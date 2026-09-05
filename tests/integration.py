#!/usr/bin/python3
"""Registration/install preservation and idle/lock lifecycle checks."""
import importlib.util,subprocess,tempfile,unittest.mock as mock
import sys,traceback
from pathlib import Path
def report_exception(kind,value,tb):
    message="".join(traceback.format_exception(kind,value,tb)).replace("%","%25").replace("\n","%0A").replace("\r","%0D")
    print("::error::"+message,flush=True)
    sys.__excepthook__(kind,value,tb)
sys.excepthook=report_exception
ROOT=Path(__file__).resolve().parents[1]
def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
register=load('register','scripts/register_xscreensaver.py')
with tempfile.TemporaryDirectory() as d:
    p=Path(d)/'xscreensaver'
    old='timeout: 0:10:00\nlock: True\nprograms: \\\n\tfoo -root \\n\\\n\tbar -root\nvisualID: default\n'
    p.write_text(old)
    assert register.register(p,Path('/usr/bin/jesussaves'))
    result=p.read_text();assert 'lock: True' in result and 'bar -root' in result and 'visualID: default' in result
    assert p.with_name(p.name+'.jesussaves.bak').read_text()==old
    assert not register.register(p,Path('/usr/bin/jesussaves'))
    prefix=Path(d)/'prefix'
    subprocess.run(['/usr/bin/python3',str(ROOT/'scripts/install.py'),'--prefix',str(prefix)],check=True,capture_output=True)
    assert (prefix/'bin/jesussaves').is_file()
    subprocess.run(['/usr/bin/python3',str(ROOT/'scripts/install.py'),'--prefix',str(prefix),'--uninstall'],check=True,capture_output=True)
    assert not (prefix/'bin/jesussaves').exists()
idle=load('idle','scripts/idle.py')
saver=object.__new__(idle.IdleSaver);saver.binary='/test/renderer';saver.backend='cpu';saver.child=None;saver.active_watch=0;saver.idle_watch=1;saver.idle=object()
saver.locked=lambda:True
with mock.patch.object(idle.subprocess,'Popen') as spawn:
    saver.start();spawn.assert_not_called()
saver.locked=lambda:False;saver.call=lambda *a:(42,)
child=mock.Mock();child.poll.return_value=None
with mock.patch.object(idle.subprocess,'Popen',return_value=child):saver.start()
assert saver.active_watch==42
saver.lock_signal(None,None,'ActiveChanged',idle.GLib.Variant('(b)',(True,)))
child.terminate.assert_called_once();assert saver.child is None
saver.child=mock.Mock();saver.child.poll.return_value=None
active=saver.child
saver.idle_signal(None,None,'WatchFired',idle.GLib.Variant('(u)',(42,)))
active.terminate.assert_called_once();assert saver.child is None
print('PASS: registration preserves settings; idempotency; install/uninstall; lock and activity stop renderer.')
