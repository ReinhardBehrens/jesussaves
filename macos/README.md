# macOS builds

Two standalone applications are built for macOS 14 Sonoma and later:

| Build | CPU heat simulation | Final flames and 3D text | Rosetta |
|---|---|---|---|
| Apple Silicon ARM64 | Native ARM NEON | Shared OpenGL shaders at 3840 × 2160 | Not required |
| Intel x86-64 | Shared NASM SSE2 | NASM CPU renderer or shared OpenGL shaders at 3840 × 2160 | Only when running this Intel build on Apple Silicon |

Download the matching ZIP from [Apple — BETA Installers](https://github.com/ReinhardBehrens/jesussaves/releases/tag/macos-v1.1.1-beta.1), unzip, and move **Jesus Saves.app** to Applications. These are standalone apps, not `.saver` plug-ins registered in macOS Screen Saver settings. Idle activation is not yet included.

## Build

On the target Mac with Xcode Command Line Tools and Homebrew:

```sh
brew install nasm sdl2
python3 -m venv .venv
source .venv/bin/activate
pip install Pillow
python3 macos/build.py
open 'build/macos/Jesus Saves.app'
```

The script chooses the host architecture, bundles SDL2 and the required assets and licenses, and writes `dist/jesussaves-macos-intel.zip` or `dist/jesussaves-macos-arm64.zip`. The signature is ad-hoc, not Apple Developer ID or notarized. macOS may require approval in Privacy & Security when opening a downloaded copy.

Default launch is full screen with GPU rendering. Escape quits. Launch the executable inside the bundle with `--windowed` for a window or `--screensaver` to quit on user input. `--gpu --snapshot` writes a 3840 × 2160 `flame.ppm`. The Intel build additionally supports `--cpu`; ARM64 does not include a software-only final renderer.

## Optional Rosetta

Use the ARM64 download on Apple Silicon; it runs natively. Rosetta is only needed to run the Intel version on Apple Silicon. Apple provides it through macOS, not as a redistributable file in this repository.

On an Apple Silicon Mac, open an Intel app and accept Apple's Rosetta prompt, or run:

```sh
/usr/sbin/softwareupdate --install-rosetta
```

This downloads Rosetta from Apple and presents its license. The optional `macos/install-rosetta.command` helper checks the host first and invokes that command. Rosetta cannot be installed on Ubuntu or Windows. See [Apple's installation guidance](https://support.apple.com/102527) and [Rosetta support lifetime](https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment).

## Implementation and validation

- Intel: `prepare.py` converts NASM object format and symbols to Mach-O. A local C stderr pointer avoids dynamic data relocations; rendering algorithms remain shared.
- ARM64: `arm64.c` implements the original scrolling turbulence, interpolated heat advection, fuel blending and cooling using NEON intrinsics. NASM cannot generate ARM instructions. Gold SDF ray marching, reflection, flame detail and heaven imagery use the same assets and GLSL as the Intel and Ubuntu GPU renderer.
- Both use a forward-compatible OpenGL 4.1 core context; snapshots use hidden SDL Cocoa windows instead of Linux EGL.
- CI builds each architecture on a matching Mac runner and tests the bundled app, its signature, 4K output and animation. Intel checks the CPU renderer; ARM checks the GPU renderer. There is no claim of physical-monitor or System Settings integration testing.
