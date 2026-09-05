# JESUS SAVES 1.1.1

## Windows installer fix

The installer now explicitly selects **Jesus Saves**, enables the screensaver, and sets a **five-minute wait** before opening Windows Screen Saver Settings. Version 1.1.0 only copied files and invoked the Control Panel installation dialog, which could leave the previous selection active.

Extract the complete new Windows ZIP, close any running Jesus Saves instance, and run **install.cmd**. Your existing sign-in requirement stays unchanged. Use `install.cmd -Minutes 10` for a different wait time. The installer checks the live Windows settings, preserves an initial settings backup, and supports reinstalling from its installed folder.

Native Windows tests cover the shipped installer, selected saver, active state, timeout, reinstall, sign-in preference preservation, and the visible selection/wait in Screen Saver Settings, alongside CPU/GPU rendering and preview tests.

## A refreshed project page

The README now has a gold cross/flame logo, navigation, platform download buttons, feature cards, icons, a creator profile, and a prominent Gospel section. Detailed setup instructions are in the linked user guide.

Downloads include the Ubuntu amd64 `.deb`, Windows x64 `.exe`/`.scr` ZIP, matching source, and checksums. Windows binaries are unsigned; native testing uses Windows Server 2025 with Mesa software OpenGL, not physical Windows 11 GPU hardware.
