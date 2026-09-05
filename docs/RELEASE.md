# JESUS SAVES 1.0.0

A 4K Ubuntu screensaver with reflective, rotating gold lettering, a heavenly background and turbulent fire.

- Complete NASM/SSE2 CPU renderer for flames and 3D text.
- NASM OpenGL hooks and GLSL effects for accelerated 4K rendering.
- GNOME/Wayland idle companion that respects the existing lock screen.
- XScreenSaver foreign-window support with selectable CPU/GPU rendering.
- Ubuntu amd64 package, complete source archive, screenshots and algorithm documentation.

Install with `sudo apt install ./jesussaves_1.0.0_amd64.deb`, then run `jesussaves --gpu` or `jesussaves --cpu`.

Target: Ubuntu 26.04.1 LTS amd64. CPU mode is substantially slower at 4K. The generated background was upscaled to 4K; final rendering and text are evaluated at 3840 × 2160. GNOME idle mode is an animation, not a password/lock-screen replacement.

See the README for idle activation, XScreenSaver registration and source builds. Code is GPL-3.0; the DejaVu font notice is included.
