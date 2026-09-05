# How the screensaver was built

The application is a hybrid graphics pipeline with two interchangeable renderers. NASM produces ELF64 object files; GCC links those objects to SDL2, libc/libm, OpenGL and EGL. There is no generated C renderer hidden behind the assembly.

## Pipeline

```text
Random gusts + seamless multiscale field
                  │
                  ▼
       NASM/SSE2 heat simulation (512 × 160)
                  │
          ┌───────┴─────────┐
          ▼                 ▼
     CPU backend        GPU backend
  SSE2 RGB emission    R32F texture upload
  CPU SDF ray tracing  GLSL fire + SDF tracing
  SSE2 interpolation   3840 × 2160 framebuffer
          └───────┬─────────┘
                  ▼
     4K image / window / XScreenSaver host
```

## 1. Heat transport and irregular fuel

`flame_step` in `src/main.asm` maintains a padded floating-point temperature grid. Four cells are processed together with SSE2. The bottom two rows receive continuously blended fuel from a seamless multiscale random field. A xorshift32 generator perturbs the horizontal fuel phase, producing nonperiodic gust sequences instead of synchronized blocks switching together.

Each destination samples two lower rows at a laterally displaced, fractional position. Bilinear horizontal interpolation transports the heat sideways; averaging the two rows moves it upward. A second, offset noise sample controls cooling:

```text
Tnew(x,y) = max(0,
    0.5 × [sample(T, x + flow, y + 1) + sample(T, x + flow, y + 2)]
    − cooling(x,y,time))
```

Top-to-bottom traversal keeps these source rows untouched during each update. Side gutters wrap samples; source addresses are clamped at vector boundaries. This is a stable visual transport approximation, not a Navier–Stokes solver or combustion model. The noise field has five spatial scales. Live random seeds vary between launches; snapshot seeds are deterministic.

## 2. GPU flame detail

The NASM OpenGL hook uploads the temperature grid as `GL_R32F`, explicitly setting its padded row length. `shaders/scene.frag` adds five-octave fractal Brownian motion (fBm), rotated/scaled noise coordinates, domain warping, and a second finer noise layer. These modulate the heat into folded flame sheets, dark gaps and flickering edges. This work happens per fragment at 4K, so details do not come solely from enlarging the simulation grid.

Nonlinear RGB curves map temperature to dark orange, yellow and pale hot cores. This is an artistic emission ramp, not a calibrated blackbody-temperature conversion. Flame emission is added over the dark background. A vertical fade prevents a hard line where the flame area begins.

## 3. CPU flame path

`src/cpu.asm` uses the same temperature simulation with a moving density field, then processes four pixels at once for RGB emission. `src/cpu_scale.asm` performs separable bilinear resampling with integer SIMD weights and saturated additive compositing. No OpenGL drawing or GLSL shader executes in CPU mode; SDL's software renderer presents an already-complete 4K image.

The CPU path has less fine flame structure than the GPU path. It is a functional software alternative, not a claim of visual or performance equivalence.

## 4. Extruded gold lettering

The build-time generator rasterizes **JESUS SAVES** using DejaVu Sans Bold at four times the original font resolution. A two-pass chamfer-distance transform generates a 1536 × 256 signed-distance field. Distances are stored in object-space units.

The runtime samples this field bilinearly and extrudes it to a 14-unit-deep solid. A chamfer term bevels the intersection of each letter's face and sides:

```text
max(distance2D, abs(z) − 7,
    (distance2D + abs(z) − 7 + 2) / sqrt(2))
```

An orthographic camera sphere-traces the rotated shape. Traces use conservative steps, a hit threshold and a fixed iteration bound. Projected bounding rectangles reject empty pixels before ray tracing. Central differences provide surface normals. The CPU implementation uses NASM/SSE2; the GPU implements the same geometry in GLSL.

Gold shading combines diffuse illumination, a narrow reflected studio-light band and warm fire light. GPU mode additionally samples the heavenly background as an environment reflection. These are simulated reflections; this is not a path tracer. A full rotation naturally makes the phrase narrow edge-on and mirrored when viewed from behind.

## 5. 4K output

GPU mode renders into a dedicated **3840 × 2160 RGBA8 framebuffer**, checks framebuffer completeness, then blits it to the display. CPU mode writes the same-sized ARGB8888 buffer directly. Window size never determines render resolution. Eight bits per RGB channel provide 16,777,216 possible colours.

Background data is embedded in the executable after build-time PNG-to-BGRA encoding. The GPU uploads it once; CPU mode caches its composite. The original generated image was smaller than 4K and was upscaled for the background asset. The font geometry and final frame are evaluated at 4K, while the heat grid is an intentional optimization.

## 6. Desktop integration

- **X11:** SDL wraps the window supplied in `XSCREENSAVER_WINDOW` or `--window-id`. GPU mode enables SDL's foreign OpenGL-window hint. Destroying the wrapper does not destroy the host window. The embedding test verifies both backends.
- **GNOME / Wayland:** a small Python/Gio companion subscribes to Mutter idle notifications and GNOME ScreenSaver lock notifications. It launches the NASM renderer on idle and terminates it on user activity or lock activation. It never requests a lock inhibitor. The SDL application calls `SDL_EnableScreenSaver()` to avoid suppressing native locking/blanking.
- **Security boundary:** the existing desktop or XScreenSaver daemon owns locking and authentication. This project only renders an animation.

## Performance and limitations

The CPU simulation is four-lane SSE2 with contiguous memory access, a small working grid and no divides inside its transport loop. Both text paths reject rays outside a projected text rectangle. GPU work is limited to the flame strip and text bounds where possible. Presentation requests vsync and caps fast runs near 60 fps.

At full 4K the CPU text tracer is expensive and may produce single-digit frame rates. GPU mode is the recommended interactive path. There is no claim of optimal AMD-specific performance; no vendor-specific instruction set is required. The flame simulation advances per presented frame, so it runs slower when rendering cannot keep up. Text drift/rotation uses wall-clock time in live runs. Fullscreen spans one display; a screensaver host can launch one process per display.

## Open-source research

There is no objective single “best” open-source flame. The following primary sources were reviewed for useful techniques and portability:

| Project / source | Relevant ideas | Application here |
|---|---|---|
| [tuxalin/procedural-tileable-shaders](https://github.com/tuxalin/procedural-tileable-shaders) (MIT) | Seamless noise, fBm, domain warping | Multiscale transport fields and warped fine emission |
| [ashima/webgl-noise](https://github.com/ashima/webgl-noise) | Portable procedural GPU noise | Reference for shader-based noise rather than frame-by-frame bitmap animation |
| [yoyoberenguer/PythonFireFx](https://github.com/yoyoberenguer/PythonFireFx) (GPL-3.0) | Temperature fields, envelope/intensity control, emission shaping | Comparison with the software fire approach and colour/brightness controls |
| [XScreenSaver manual](https://manpages.debian.org/testing/xscreensaver/xscreensaver.1.en.html) | Host-window contract | `XSCREENSAVER_WINDOW` support |
| [SDL foreign OpenGL windows](https://wiki.libsdl.org/SDL2/SDL_HINT_VIDEO_FOREIGN_WINDOW_OPENGL) | Wrapping a host's window | GPU embedding initialization |
| [SDL_EnableScreenSaver](https://wiki.libsdl.org/SDL2/SDL_EnableScreenSaver) | Preserve native screen blanking | Called explicitly after video initialization |

The implementation is original project code applying these general techniques; those repositories were not vendored or represented as NASM ports. Font notices and asset provenance are kept separately.
