# CPU and GPU hooks

These are ELF symbols in the NASM object files. They are link-time integration points, not a dynamically loaded plugin ABI. Use the x86-64 System V ABI: integer/pointer arguments in RDI, RSI, RDX, RCX, R8, R9; the float time argument in XMM0. Stack alignment is 16 bytes before external calls.

| Entry point | Inputs | Result / responsibility |
|---|---|---|
| `flame_step` | None | Advance shared padded float heat field by one tick; SSE2, four cells at once |
| `cpu_init` | RDI = SDL window | EAX = 0 / -1; create software presentation objects |
| `cpu_render` | XMM0 = seconds; EDI = background-only flag | Render both CPU flames and CPU text into `scene`, without a display |
| `cpu_draw` | Same as `cpu_render` | Render and present a complete CPU frame; EAX = 0 / negative SDL error |
| `cpu_flame_color` | None | Convert shared heat to CPU RGB pixels with density modulation |
| `cpu_shutdown` | None | Destroy software presentation objects |
| `gpu_configure` | None | Set SDL OpenGL 3.3 attributes before window creation |
| `gpu_init` | RDI = SDL OpenGL window | EAX = 0 / -1; initialize GPU resources |
| `gpu_headless` | None | EAX = 0 / -1; initialize a surfaceless EGL renderer |
| `gpu_draw` | XMM0 = seconds; EDI = background-only flag | Upload heat; render 4K GPU flames and text; present when a window exists |
| `gpu_readback` | None | Read the GPU framebuffer, flip rows, and write top-down `scene` |
| `gpu_shutdown` | None | Release SDL/EGL context resources |

`heat` is `(160+2) × (512+2)` float32 values. The visible first cell is `heat + 4`; row stride is 514 floats. `scene` is a top-down 3840 × 2160 buffer of opaque ARGB8888 words (BGRA bytes on x86-64). Calls use shared global state and must stay on one rendering thread; they are not reentrant.

The command line chooses `--cpu` or `--gpu`; it does not silently substitute software OpenGL for the NASM CPU renderer. A GPU driver may itself use software rasterization; `--cpu` is the unambiguous NASM software path.

For new effects, extend `cpu_render` / `compose_scene` in the CPU path and `shaders/scene.frag` in the GPU path. Keep the shared dimensions, image orientation and time contract consistent. NASM owns GPU setup, uniforms, uploads, framebuffer binding and readback. Portable GLSL owns GPU per-fragment computation.
