/* SPDX-License-Identifier: GPL-3.0-only */
#include <SDL.h>
extern void gpu_configure(void);
extern int gpu_init(SDL_Window *);
static SDL_Window *snapshot_window;
static void close_snapshot(void) {
    if (snapshot_window) SDL_DestroyWindow(snapshot_window);
    SDL_Quit();
}
int mac_headless(void) {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return -1;
    gpu_configure();
    snapshot_window = SDL_CreateWindow("Jesus Saves snapshot", 0, 0, 32, 32,
                                       SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN);
    if (!snapshot_window) { SDL_Quit(); return -1; }
    atexit(close_snapshot);
    return gpu_init(snapshot_window);
}
