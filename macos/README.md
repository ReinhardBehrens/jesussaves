# macOS build

The Intel macOS port builds the shared NASM CPU and GPU renderers into a standalone `Jesus Saves.app`. The GitHub Actions **macOS Intel build** workflow produces `jesussaves-macos-intel.zip`. This is an application, not yet a `.saver` plug-in registered in macOS Screen Saver settings.

## Build

On an Intel Mac with Xcode Command Line Tools and Homebrew:

```sh
brew install nasm sdl2
python3 -m venv .venv
source .venv/bin/activate
pip install Pillow
python3 macos/build.py
open 'build/macos/Jesus Saves.app'
```

The ZIP includes SDL2. The build uses an ad-hoc signature, not an Apple Developer ID signature or notarization. macOS may require approval in Privacy & Security when opening a downloaded copy.

The default launch uses the GPU; run `build/macos/jesussaves --cpu` for NASM CPU rendering or add `--window` for a windowed preview. Escape quits. `--cpu --snapshot` writes a 3840 × 2160 `flame.ppm`.

## Compatibility and implementation

- Intel x86-64 only. Apple Silicon requires Rosetta; native ARM64 is not implemented or tested. Apple documents general Rosetta support through macOS 27: https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment
- `prepare.py` changes object format, public symbol prefixes and macOS's stderr symbol. Rendering code remains shared with Ubuntu and Windows.
- macOS uses a forward-compatible OpenGL 4.1 core context for the existing GLSL shaders. Snapshot rendering uses a hidden SDL Cocoa window instead of Linux EGL.
- No Linux XScreenSaver embedding support on macOS. Automatic idle activation and a native `.saver` plug-in remain future work.
- The CI workflow assembles and links on macOS and checks the CPU 4K snapshot and application signature. GPU behavior and Apple Silicon compatibility require testing on actual Macs.
