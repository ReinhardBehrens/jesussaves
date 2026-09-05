<div align="center">

# ✦ JESUS SAVES ✦
### Light. Hope. Salvation.

**A 4K screensaver with reflective gold lettering, living flames, and a heavenly sky.**

[![Ubuntu download](https://img.shields.io/badge/Download-Ubuntu%20.deb-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://github.com/ReinhardBehrens/jesussaves/releases/download/v1.0.0/jesussaves_1.0.0_amd64.deb)
[![Release](https://img.shields.io/github/v/release/ReinhardBehrens/jesussaves?style=for-the-badge&color=c99a36)](https://github.com/ReinhardBehrens/jesussaves/releases/latest)
[![License](https://img.shields.io/badge/License-GPL%203.0-blue?style=for-the-badge)](LICENSE)

[**Download**](#download) · [**The Gospel**](#the-gospel-of-jesus-christ) · [**Install**](#install-on-ubuntu) · [**How it works**](docs/ARCHITECTURE.md)

</div>

Reflective gold **JESUS SAVES** lettering floats and rotates above turbulent flames, against a heavenly cloudscape fading into black. A tribute to the dramatic 3D screensavers of the 1990s, built with **NASM x86-64 assembly**, **SSE2**, and an optional **OpenGL 3.3 / GLSL** renderer.

[Download Ubuntu packages](https://github.com/ReinhardBehrens/jesussaves/releases) · [Algorithms and architecture](docs/ARCHITECTURE.md) · [Rendering hooks](docs/HOOKS.md)

[![Jesus Saves 4K screensaver — reflective gold lettering, heavenly clouds, and turbulent fire](docs/screenshot.png)](docs/screenshot-4k.png)

*Actual GPU-rendered screenshot. Click for the full 3840 × 2160 image.*

## Download

| Community edition | Download |
|---|---|
| **Ubuntu 26.04.1 LTS · Intel / AMD 64-bit** | [**Download the `.deb` installer**](https://github.com/ReinhardBehrens/jesussaves/releases/download/v1.0.0/jesussaves_1.0.0_amd64.deb) |
| Matching source code | [Source archive](https://github.com/ReinhardBehrens/jesussaves/releases/download/v1.0.0/jesussaves-1.0.0-source.tar.gz) |
| Verify your download | [SHA-256 checksums](https://github.com/ReinhardBehrens/jesussaves/releases/download/v1.0.0/SHA256SUMS) |

Free to download, study, and share under the GPL. Windows 11 packaging is in development; the published installer above is for Ubuntu.

## The Gospel of Jesus Christ

> “For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.”
>
> **John 3:16 · King James Version**

**The good news is Jesus Christ.** God loves us, yet sin separates us from Him. We cannot earn our salvation through achievements or good works. Jesus, the Son of God, lived without sin, died for our sins, was buried, and rose again on the third day. Through Him, God offers forgiveness, reconciliation, and eternal life.

- **Our need:** all have sinned and fall short of God's glory — *Romans 3:23*.
- **God's love:** Christ died for us while we were still sinners — *Romans 5:8*.
- **Christ's victory:** Jesus died for our sins, was buried, and rose again — *1 Corinthians 15:3–4*.
- **God's gift:** salvation comes by grace through faith, not by works — *Ephesians 2:8–9*.
- **Our response:** repent and believe the Gospel; confess Jesus as Lord and believe God raised Him from the dead — *Mark 1:15; Romans 10:9–13*.

Turn to Jesus in faith. Speak honestly to Him in prayer, ask His forgiveness, and follow Him. A prayer is not a formula that earns salvation; our trust is in Christ. Read the Gospel of John and seek a Christian church where you can learn the Scriptures, worship, and grow with others.

This project shares that message through art. The clouds and flames are an artistic setting, not a claim to depict heaven or the afterlife literally.

## Features

- **3840 × 2160 rendering in both backends**, including when previewed in a smaller window.
- Extruded, bevelled 3D lettering, full horizontal rotation, gentle rocking, and independent drifting motion.
- Reflective gold shading, moving highlights, and warm fire reflections.
- Continuous turbulent heat transport, random gusts, and irregular fuel. GPU mode adds fine animated flame sheets and dark pockets at output resolution.
- Two complete rendering paths: **CPU flames + CPU text**, or **CPU heat simulation + GPU flames and text**.
- GNOME/Wayland idle companion for current Ubuntu, plus native-window integration for XScreenSaver on X11.
- Deterministic 4K snapshots, a background export, and documented assembly entry points.

## Install on Ubuntu

The release target is **Ubuntu 26.04.1 LTS, amd64**. The project is built and exercised on that release. Source CI also covers Ubuntu 24.04. Other architectures are not supported by this x86-64 assembly implementation.

Download the `.deb` from [Releases](https://github.com/ReinhardBehrens/jesussaves/releases), then:

```bash
sudo apt install ./jesussaves_1.0.0_amd64.deb
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

The Windows edition includes **JesusSaves.exe**, a native **JesusSaves.scr** screensaver, and the SDL2 runtime. Extract the complete Windows ZIP from [Releases](https://github.com/ReinhardBehrens/jesussaves/releases), then run `install.cmd`. It installs for your user account and opens Windows Screen Saver Settings. Choose your wait time and sign-in preference, then click **Apply**.

Use **Settings** to select GPU or CPU rendering. Moving the mouse or pressing a key dismisses screensaver mode. The small Windows preview uses CPU rendering; the fullscreen saver uses your saved choice. Portable mode exits with Escape. The saver uses the primary display.

```powershell
.\JesusSaves.exe --gpu --windowed
.\JesusSaves.exe --cpu --windowed
.\JesusSaves.scr /c
.\JesusSaves.scr /s
```

Windows requires an Intel/AMD x64 CPU; GPU mode requires an OpenGL 3.3 driver. The community binaries are unsigned. Native CI runs on Windows Server 2025 with Mesa software OpenGL; physical Windows 11 GPU testing has not been performed. [Windows installation and removal](windows/README-Windows.md) · [Windows build instructions](windows/BUILD.md).

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
python3 scripts/package.py                # dist/jesussaves_1.0.0_amd64.deb
```

GPU snapshots use an EGL surfaceless context; CPU snapshots do not need a display. A software OpenGL driver can also run GPU tests with `LIBGL_ALWAYS_SOFTWARE=1`. Snapshots use a fixed seed; live runs seed the gust generator from the performance counter. `FLAME_TIME` is clamped to 0–60 seconds for bounded snapshot generation.

Validated on Ubuntu 26.04.1: both renderers, exact 4K output, animation bounds across multiple rotations, changing flame patterns, native X11 embedding, CLI errors, registration/install behavior, and idle/lock lifecycle logic. The GNOME D-Bus interfaces were checked in a live session; automated lifecycle tests cover launch suppression while locked and stopping on activity/lock. See [architecture notes](docs/ARCHITECTURE.md) for performance limits and source research.

## Artwork and licensing

Code uses the repository's **GPL-3.0** license. The embedded DejaVu-derived lettering retains the [DejaVu font notice](licenses/DejaVu.txt).

The background was created with OpenAI's built-in image generator and exported to a 4K asset. The generator returned a 1672 × 941 source; the 3840 × 2160 background is an upscale. Text and final rendering are computed at 4K. The heat simulation is deliberately lower resolution, with GPU procedural detail evaluated at final resolution. [Asset provenance and prompts](docs/ASSETS.md) document this distinction.
