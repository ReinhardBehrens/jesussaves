// SPDX-License-Identifier: GPL-3.0-only
// System integration only; flames, geometry and pixels are NASM/GLSL.
#include "platform.h"
#include <errno.h>
#include <ctype.h>
#include <string.h>
FILE *bridge_stderr;
static SDL_Window *hidden;
static HWND preview_parent;
static int saver;
static POINT initial_mouse;
static ULONGLONG started;
static const char *settings_key="Software\\JesusSaves";

int SYSV bridge_fprintf(FILE *stream, const char *format, const char *message) {
    return fprintf(stream, format, message);
}
int SYSV bridge_SDL_SetError(const char *format, const char *message) {
    return strcmp(format,"%s")==0 ? SDL_SetError("%s",message) : SDL_SetError("%s",format);
}
int SYSV bridge_load_gl(void) { return load_gl(); }
int SYSV bridge_headless(void) {
    if (SDL_Init(SDL_INIT_VIDEO)<0) return -1;
    SDL_EnableScreenSaver();
    gpu_configure();
    hidden=SDL_CreateWindow("Jesus Saves snapshot",0,0,64,64,SDL_WINDOW_OPENGL|SDL_WINDOW_HIDDEN);
    return hidden ? gpu_init(hidden) : -1;
}
// A Windows preview is our own child HWND in the Control Panel host.
// Do not subclass or destroy an HWND owned by another process.
SDL_Window *SYSV bridge_SDL_CreateWindowFrom(const void *native) {
    HWND parent=(HWND)native;
    RECT r;
    if (!IsWindow(parent) || !GetClientRect(parent,&r)) {
        SDL_SetError("Invalid preview host window"); return NULL;
    }
    Uint32 flags=SDL_WINDOW_HIDDEN|SDL_WINDOW_BORDERLESS;
    if (SDL_GetHintBoolean(SDL_HINT_VIDEO_FOREIGN_WINDOW_OPENGL,SDL_FALSE)) flags|=SDL_WINDOW_OPENGL;
    SDL_Window *w=SDL_CreateWindow("Jesus Saves preview",0,0,r.right-r.left,r.bottom-r.top,flags);
    if (!w) return NULL;
    SDL_SysWMinfo info; SDL_VERSION(&info.version);
    if (!SDL_GetWindowWMInfo(w,&info)) { SDL_DestroyWindow(w); return NULL; }
    HWND child=info.info.win.window;
    LONG_PTR style=GetWindowLongPtrW(child,GWL_STYLE);
    SetWindowLongPtrW(child,GWL_STYLE,(style & ~WS_POPUP)|WS_CHILD);
    SetLastError(0);
    if (!SetParent(child,parent) && GetLastError()!=0) {
        SDL_SetError("Cannot attach screensaver preview"); SDL_DestroyWindow(w); return NULL;
    }
    SetWindowPos(child,NULL,0,0,r.right-r.left,r.bottom-r.top,SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED);
    preview_parent=parent;
    SDL_ShowWindow(w);
    return w;
}
int SYSV bridge_SDL_PollEvent(SDL_Event *e) {
    if (preview_parent && !IsWindow(preview_parent)) {
        memset(e,0,sizeof(*e)); e->type=SDL_QUIT; return 1;
    }
    if (saver && GetTickCount64()-started>1000) {
        POINT p; GetCursorPos(&p);
        int active=abs(p.x-initial_mouse.x)>4 || abs(p.y-initial_mouse.y)>4;
        for (int k=1;k<256 && !active;k++) active=(GetAsyncKeyState(k)&0x8000)!=0;
        if (active) { memset(e,0,sizeof(*e)); e->type=SDL_QUIT; return 1; }
    }
    int result=SDL_PollEvent(e);
    if (result && saver && (e->type==SDL_KEYDOWN || e->type==SDL_MOUSEBUTTONDOWN)) e->type=SDL_QUIT;
    return result;
}
static int cpu_setting(void) {
    DWORD value=0, size=sizeof(value);
    RegGetValueA(HKEY_CURRENT_USER,settings_key,"CPU",RRF_RT_REG_DWORD,NULL,&value,&size);
    return value==1;
}
static INT_PTR CALLBACK config_proc(HWND dialog, UINT msg, WPARAM wp, LPARAM lp) {
    (void)lp;
    if (msg==WM_INITDIALOG) {
        CheckRadioButton(dialog,101,102,cpu_setting()?102:101); return TRUE;
    }
    if (msg==WM_COMMAND) {
        if (LOWORD(wp)==IDOK) {
            DWORD value=IsDlgButtonChecked(dialog,102)==BST_CHECKED;
            HKEY key;
            LONG status=RegCreateKeyExA(HKEY_CURRENT_USER,settings_key,0,NULL,0,KEY_SET_VALUE,NULL,&key,NULL);
            if (status==ERROR_SUCCESS) {
                status=RegSetValueExA(key,"CPU",0,REG_DWORD,(const BYTE*)&value,sizeof(value));
                RegCloseKey(key);
            }
            if (status!=ERROR_SUCCESS) { MessageBoxA(dialog,"Unable to save settings.","Jesus Saves",MB_ICONERROR); return TRUE; }
            EndDialog(dialog,0); return TRUE;
        }
        if (LOWORD(wp)==IDCANCEL) { EndDialog(dialog,0); return TRUE; }
    }
    return FALSE;
}
static HWND parse_handle(const char *text) {
    char *end; errno=0;
    if (!text || !isdigit((unsigned char)*text)) return NULL;
    unsigned long long n=strtoull(text,&end,10);
    if (errno || *end || !n || !IsWindow((HWND)(uintptr_t)n)) return NULL;
    return (HWND)(uintptr_t)n;
}
static __attribute__((noinline)) int invoke_nasm(int argc, char **argv) {
    return nasm_main(argc,argv);
}
int main(int argc,char **argv) {
    bridge_stderr=stderr;
    SDL_SetMainReady();
    SetProcessDPIAware();
    const char *arg=argc>1?argv[1]:NULL;
    const char *ext=strrchr(argv[0],'.');
    int config=!arg && ext && _stricmp(ext,".scr")==0;
    if (arg && (arg[0]=='/' || (arg[0]=='-' && arg[1]!='-'))) {
        if (!arg[1]) return 2;
        char mode=(char)tolower((unsigned char)arg[1]);
        if (arg[2] && arg[2]!=':') return 2;
        const char *handle=arg[2]==':'?arg+3:(argc>2?argv[2]:NULL);
        if (mode=='c') config=1;
        else if (mode=='s' && !arg[2] && argc==2) saver=1;
        else if (mode=='p') {
            HWND parent=parse_handle(handle); if (!parent) return 2;
            char id[32]; snprintf(id,sizeof(id),"0x%llx",(unsigned long long)(uintptr_t)parent);
            char *preview[]={argv[0],"--cpu","--window-id",id,NULL};
            return invoke_nasm(4,preview);
        } else return 2;
        if (config) {
            HWND parent=handle?parse_handle(handle):NULL;
            return DialogBoxParamA(GetModuleHandleA(NULL),MAKEINTRESOURCEA(1),parent,config_proc,0)==-1?1:0;
        }
    }
    if (config) return DialogBoxParamA(GetModuleHandleA(NULL),MAKEINTRESOURCEA(1),NULL,config_proc,0)==-1?1:0;
    GetCursorPos(&initial_mouse); started=GetTickCount64();
    char *run[]={argv[0],cpu_setting()?"--cpu":"--gpu",NULL};
    int result=invoke_nasm(saver?2:argc,saver?run:argv);
    if (hidden) { SDL_DestroyWindow(hidden); SDL_Quit(); }
    return result;
}
