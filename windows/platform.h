// SPDX-License-Identifier: GPL-3.0-only
#ifndef JESUSSAVES_PLATFORM_H
#define JESUSSAVES_PLATFORM_H
#define SDL_MAIN_HANDLED
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <SDL.h>
#include <SDL_opengl.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#define SYSV __attribute__((sysv_abi))
extern int SYSV nasm_main(int, char**);
extern void SYSV gpu_configure(void);
extern int SYSV gpu_init(SDL_Window*);
int load_gl(void);
#endif
