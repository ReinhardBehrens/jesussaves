# JESUS SAVES - Windows 11 x64

Reflective gold 3D lettering above turbulent flames and a heavenly cloudscape.
Both rendering paths produce a 3840 x 2160 frame. Intel and AMD x64 CPUs supported.

## Install as a screensaver

1. Extract the entire ZIP to a folder. Keep SDL2.dll beside the executable.
2. Double-click install.cmd. It copies the program into your own
   %LOCALAPPDATA%\JesusSaves folder, selects Jesus Saves, enables it with a five-minute wait, and opens Windows Screen Saver Settings.
3. Jesus Saves is already selected and enabled with a five-minute wait. Adjust the wait time if desired, then Apply.
4. Use Settings to choose GPU (recommended) or CPU rendering.

No administrator access is needed. Windows owns the lock screen and passwords.
The installer preserves your existing sign-in requirement. To set another wait during installation, run install.cmd -Minutes 10. The screensaver
exits when you move the mouse or press a key. It uses the primary display.

This community build is unsigned; Windows may show an unknown-publisher prompt.
Download it from https://github.com/ReinhardBehrens/jesussaves/releases only.

The first installation saves your previous selection, active state and timeout in
%LOCALAPPDATA%\JesusSaves\previous-screensaver.json. Reinstalling preserves that
backup. Close Screen Saver Settings and Jesus Saves before updating.

## Portable use

Double-click JesusSaves.exe to run fullscreen. Escape exits portable mode.
From a terminal:

    JesusSaves.exe --gpu --windowed
    JesusSaves.exe --cpu --windowed
    JesusSaves.exe --cpu --snapshot
    JesusSaves.scr /c
    JesusSaves.scr /s

Snapshots write flame.ppm in the current folder. GPU mode requires an OpenGL 3.3
capable graphics driver. CPU mode uses NASM/SSE2 for flames and text and is much
slower at 4K. Screen Saver Settings' small preview always uses CPU rendering.
GPU snapshots create a hidden SDL window, so they require a Windows desktop.

To uninstall, select a different screensaver (or None) in Windows settings,
close Jesus Saves, then delete %LOCALAPPDATA%\JesusSaves. The optional renderer
preference is stored at HKCU\Software\JesusSaves. No service is installed.

## How it is built

The same six NASM sources as Ubuntu supply simulation, CPU rendering, and GPU
host hooks. A generated, typed C ABI bridge translates between System V AMD64
assembly calls and Windows x64 library calls. No flame or text rendering is
implemented in C. GPU kernels are GLSL, loaded through SDL's OpenGL entry points.
The small Windows platform layer handles screensaver arguments, input activity,
settings, and hidden snapshot windows. See docs/ARCHITECTURE.md in the repository.

Code: GPL-3.0. SDL2: zlib license (SDL2-LICENSE.txt). DejaVu font notice is in
licenses/DejaVu.txt. Source and notices accompany the community release.
