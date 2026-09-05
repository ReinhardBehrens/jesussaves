# JESUS SAVES 1.1.0

**Community downloads for Ubuntu and Windows 11 x64.**

A 4K screensaver with reflective, rotating gold JESUS SAVES lettering, a heavenly background, and turbulent fire. The repository README includes the Gospel of Jesus Christ, screenshots, installation instructions, and the rendering algorithms.

- **Ubuntu:** download `jesussaves_1.1.0_amd64.deb`, then install with `sudo apt install ./jesussaves_1.1.0_amd64.deb`.
- **Windows 11 x64:** extract `jesussaves-1.1.0-windows-x64.zip`, then run `install.cmd` to open Screen Saver Settings. The ZIP also includes a portable `.exe` and a `.scr` screensaver.
- **Source:** the matching source archive includes both platforms. Checksums accompany the downloads.

Both platforms share the NASM/SSE2 heat simulation and CPU text/flame renderer. GPU mode uses NASM OpenGL hooks and GLSL effects. Windows adds typed ABI bridges, native settings, preview embedding, and input dismissal. Ubuntu includes GNOME/Wayland idle integration and XScreenSaver support.

Ubuntu target: 26.04.1 LTS amd64, with source CI on 24.04 as well. Windows tests run on Windows Server 2025 CI with Mesa software OpenGL; physical Windows 11 GPU testing has not been performed. Windows binaries are unsigned. CPU mode is substantially slower at 4K; GPU mode requires OpenGL 3.3.

The generated background was upscaled to 4K; final rendering and text are evaluated at 3840 × 2160. The animation does not replace the operating system's lock screen or password protection. GPL-3.0 source, SDL2 license, and DejaVu notices are included.
