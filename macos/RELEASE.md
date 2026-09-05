Native macOS 14+ standalone apps for Intel and Apple Silicon, rendering at 3840 × 2160.

- **Apple Silicon (M-series):** download `jesussaves-macos-arm64.zip`. Native NEON heat simulation and shared GPU fire/text shaders; no Rosetta required.
- **Intel Mac:** download `jesussaves-macos-intel.zip`. Shared NASM CPU/GPU renderer. Running this build on Apple Silicon requires Apple's optional Rosetta translation.
- Unzip, move Jesus Saves.app to Applications, and open it. Escape exits.
- These preview apps are ad-hoc signed and not notarized; macOS may require approval in Privacy & Security.
- These are standalone apps, not yet registered in macOS Screen Saver settings. ARM64 has no software-only final renderer.

Both packages are compiled on matching Mac CI runners. The bundled Intel CPU/GPU and ARM64 GPU render paths are checked for 4K output and animation, with a live GPU-window smoke test. The Intel CPU renderer is also tested under Apple Rosetta on ARM. Source and SHA-256 checksums are included.
