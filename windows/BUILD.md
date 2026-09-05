# Build the Windows edition from Ubuntu

Install the cross-toolchain:

```sh
sudo apt install nasm gcc-mingw-w64-x86-64 python3-pil curl
mkdir -p build
curl -fL https://www.libsdl.org/release/SDL2-devel-2.32.10-mingw.tar.gz -o build/SDL2.tar.gz
echo '83a5d74012311edc3c0d40ea6faecbe57ad692aa033fa5dc273cc937e3938ff2  build/SDL2.tar.gz' | sha256sum -c -
tar -xzf build/SDL2.tar.gz -C build
SDL_ROOT="$PWD/build/SDL2-2.32.10/x86_64-w64-mingw32" python3 windows/build.py
python3 windows/package.py
```

The output is `dist/jesussaves-VERSION-windows-x64.zip` with a SHA-256 sidecar.
The official SDL2 runtime is included under its zlib license. MinGW's compiler
runtime is statically linked; no MinGW runtime DLL is required. Normal graphics
drivers are supplied by Windows/the hardware vendor, not bundled with the app.

`windows/test.py` runs on Windows with Python and Pillow. It checks native CPU
and GPU snapshots, live rendering, argument validation, the configuration
dialog, preview embedding and input dismissal. The GitHub workflow installs a
checksum-pinned Mesa driver only in its test environment, because hosted
Windows runners lack a physical OpenGL 3.3 GPU. This driver is not in the ZIP.

`WIN_CC`, `WINDRES`, `NASM`, and `WIN_CFLAGS` can override toolchain paths.
Generated COFF sources and ABI bridges remain under `build/windows`; edit the
shared `src/*.asm` files or generator instead of generated output.
