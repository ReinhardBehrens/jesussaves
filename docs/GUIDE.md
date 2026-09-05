# 📖 User guide

[← Back to the project](../README.md)

## Install on Ubuntu

The release target is **Ubuntu 26.04.1 LTS, amd64**. The project is built and exercised on that release. Source CI also covers Ubuntu 24.04. Other architectures are not supported by this x86-64 assembly implementation.

Download the `.deb` from [Releases](https://github.com/ReinhardBehrens/jesussaves/releases), then:

```bash
sudo apt install ./jesussaves_1.1.1_amd64.deb
jesussaves --gpu
```

Use **Escape** to exit. “Jesus Saves 4K” is also available in the applications menu. A 4K monitor is not required: the finished 4K frame is scaled to the window or display.

```bash
jesussaves --cpu                 # complete CPU renderer; no GPU shading
jesussaves --gpu --windowed      # smaller preview window, still a 4K render
```

| Backend | Flame rendering | Gold text | Requirements / tradeoff |
|---|---|---|---|
| `--gpu` (default) | SSE2 heat simulation; procedural GLSL emission and detail | GPU distance-field ray tracing | OpenGL 3.3; preferred for smooth 4K animation |
| `--cpu` | SSE2 heat transport, density modulation, RGB conversion and compositing | NASM/SSE2 distance-field ray tracing | Any x86-64 CPU; considerably slower at 4K; different fine flame detail |

The GPU is controlled through NASM bindings. GPU kernels are GLSL, compiled by the graphics driver; NASM does not assemble AMD or NVIDIA GPU instructions. Both AMD and Intel x86-64 CPUs are supported. GPU mode uses standard OpenGL rather than a vendor-specific API.

## Make it your screensaver

### Ubuntu GNOME / Wayland

Enable the optional per-user idle companion:

```bash
systemctl --user daemon-reload
systemctl --user enable --now jesussaves-idle.service
```

It starts the animation after **four minutes of inactivity**, stops it when you return, and stops it when GNOME's lock screen becomes active. **GNOME continues to handle locking and passwords.** This is an idle animation, not a replacement lock screen, and it does not change your existing lock or display-blanking settings. If GNOME blanks/locks earlier than four minutes, choose a shorter animation timeout.

To change the delay or select the CPU backend:

```bash
systemctl --user edit jesussaves-idle.service
```

```ini
[Service]
Environment=JESUSSAVES_IDLE_SECONDS=120
Environment=JESUSSAVES_BACKEND=cpu
```

Then run `systemctl --user restart jesussaves-idle.service`. To disable the companion:

```bash
systemctl --user disable --now jesussaves-idle.service
```

The companion requires GNOME's Mutter idle-monitor and ScreenSaver D-Bus interfaces. Other Wayland compositors can run the animation directly but need their own idle integration. SDL's normal screensaver inhibition is explicitly disabled so this app does not keep the session unlocked.

### XScreenSaver / X11 sessions

```bash
sudo apt install xscreensaver
jesussaves-register
xscreensaver-settings
```

Select **Jesus Saves 4K**. On older XScreenSaver releases, the settings command may be `xscreensaver-demo`. Registration backs up an existing `~/.xscreensaver` and preserves its timeout and lock settings. Do not run competing screen-locking daemons in the same session.

The module accepts `XSCREENSAVER_WINDOW` and `--window-id 0xID`; it draws into the host's existing window instead of opening a second fullscreen window. `--screensaver` requires a host window. The package installs an XScreenSaver configuration panel with CPU/GPU selection.

## Windows 11 x64

The Windows edition includes **JesusSaves.exe**, a native **JesusSaves.scr** screensaver, and the SDL2 runtime. Extract the complete Windows ZIP from [Releases](https://github.com/ReinhardBehrens/jesussaves/releases), then run `install.cmd`. It installs for your user account and selects and enables Jesus Saves with a five-minute wait, then opens Windows Screen Saver Settings. Your sign-in preference is preserved.

Use **Settings** to select GPU or CPU rendering. Moving the mouse or pressing a key dismisses screensaver mode. The small Windows preview uses CPU rendering; the fullscreen saver uses your saved choice. Portable mode exits with Escape. The saver uses the primary display.

```powershell
.\JesusSaves.exe --gpu --windowed
.\JesusSaves.exe --cpu --windowed
.\JesusSaves.scr /c
.\JesusSaves.scr /s
```

Windows requires an Intel/AMD x64 CPU; GPU mode requires an OpenGL 3.3 driver. The community binaries are unsigned. Native CI runs on Windows Server 2025 with Mesa software OpenGL; physical Windows 11 GPU testing has not been performed. [Windows installation and removal](../windows/README-Windows.md) · [Windows build instructions](../windows/BUILD.md).

## Build from source

```bash
sudo apt install build-essential nasm python3-pil python3-gi \
    libsdl2-2.0-0 libgl1 libegl1

git clone https://github.com/ReinhardBehrens/jesussaves.git
cd jesussaves
make -j2
./build/jesussaves --gpu
```

GCC is used to **link** the NASM object files with system libraries. There is no C/C++ renderer. Python only packs assets during the build and supplies optional desktop integration and tests. With dependencies installed, no font download, API key, or internet access is needed to build or run. Windows uses a small C platform layer to bridge calling conventions and integrate with Screen Saver Settings; rendering stays in NASM and GLSL.

`make install` installs under `~/.local`. This does not automatically enable idle activation. Use `~/.local/bin/jesussaves-register --binary ~/.local/bin/jesussaves` for a user-installed XScreenSaver entry. Stop the idle service before `make uninstall`.

## Export and test

```bash
./build/jesussaves --gpu --snapshot        # writes flame.ppm at 3840 × 2160
./build/jesussaves --cpu --snapshot
./build/jesussaves --background            # 4K background without text/fire
FLAME_TIME=9 ./build/jesussaves --snapshot  # a particular animation pose
FLAME_FRAMES=120 ./build/jesussaves --gpu --windowed

make test
python3 tests/embedding.py                 # requires a working X11 display
python3 scripts/package.py                # dist/jesussaves_1.1.1_amd64.deb
```

GPU snapshots use an EGL surfaceless context; CPU snapshots do not need a display. A software OpenGL driver can also run GPU tests with `LIBGL_ALWAYS_SOFTWARE=1`. Snapshots use a fixed seed; live runs seed the gust generator from the performance counter. `FLAME_TIME` is clamped to 0–60 seconds for bounded snapshot generation.

Validated on Ubuntu 26.04.1: both renderers, exact 4K output, animation bounds across multiple rotations, changing flame patterns, native X11 embedding, CLI errors, registration/install behavior, and idle/lock lifecycle logic. The GNOME D-Bus interfaces were checked in a live session; automated lifecycle tests cover launch suppression while locked and stopping on activity/lock. See [architecture notes](ARCHITECTURE.md) for performance limits and source research.

## Artwork and licensing

Code uses the repository's **GPL-3.0** license. The embedded DejaVu-derived lettering retains the [DejaVu font notice](../licenses/DejaVu.txt).

The background was created with OpenAI's built-in image generator and exported to a 4K asset. The generator returned a 1672 × 941 source; the 3840 × 2160 background is an upscale. Text and final rendering are computed at 4K. The heat simulation is deliberately lower resolution, with GPU procedural detail evaluated at final resolution. [Asset provenance and prompts](ASSETS.md) document this distinction.
