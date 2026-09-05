/* SPDX-License-Identifier: GPL-3.0-only
 * Native Apple Silicon host. Shared GLSL performs the 4K text/fire rendering;
 * the NASM heat-advection algorithm is translated to ARM NEON intrinsics.
 */
#define GL_SILENCE_DEPRECATION
#include <SDL.h>
#include <OpenGL/gl3.h>
#include <arm_neon.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <limits.h>

#define W 3840
#define H 2160
#define STRIDE 514
static float heat[162][STRIDE], packed[160][512];
static float *turbulence;
static uint32_t rng=0x971f253b, tick, gust;
static char resources[PATH_MAX];
static void die(const char *message) { fprintf(stderr,"Jesus Saves: %s\n",message); exit(1); }
static void *asset(const char *name, size_t expected) {
    char path[PATH_MAX];
    if (snprintf(path,sizeof path,"%s/%s",resources,name)>=(int)sizeof path) die("Asset path too long");
    FILE *f=fopen(path,"rb"); if(!f) die(path);
    if(fseek(f,0,SEEK_END)) die("Cannot seek asset");
    long size=ftell(f); if(size<0 || (expected && (size_t)size!=expected)) die("Invalid asset size");
    rewind(f); char *data=calloc((size_t)size+1,1); if(!data) die("Out of memory");
    if(fread(data,1,(size_t)size,f)!=(size_t)size) die("Cannot read asset");
    fclose(f); return data;
}
static void step(void) {
    rng^=rng<<13; rng^=rng>>17; rng^=rng<<5; rng|=1;
    gust=(gust+(rng&7)-3)&127; tick++;
    float *fuel=turbulence+((tick>>1)&255)*512;
    for(int x=0;x<512;x+=4) {
        float32x4_t target=vmaxq_f32(vaddq_f32(vmulq_n_f32(vld1q_f32(fuel+((gust*4+x)&511)),.8f),vdupq_n_f32(.52f)),vdupq_n_f32(0));
        float32x4_t old=vld1q_f32(&heat[160][x+1]);
        float32x4_t v=vaddq_f32(old,vmulq_n_f32(vsubq_f32(target,old),.09f));
        vst1q_f32(&heat[160][x+1],v); vst1q_f32(&heat[161][x+1],v);
    }
    for(int y=1;y<162;y++){heat[y][0]=heat[y][512];heat[y][513]=heat[y][1];}
    for(int y=0;y<160;y++) {
        float *flow=turbulence+((tick+160-y)&255)*512;
        for(int x=0;x<512;x+=4) {
            unsigned j=((tick>>2)*4+x)&511;
            float offset=flow[j]*2.7f+3.f; int shift=(int)offset;
            float frac=offset-shift; int xx=x+shift-3;
            if(xx<0)xx=0; if(xx>508)xx=508;
            float32x4_t a=vld1q_f32(&heat[y+1][xx+1]), b=vld1q_f32(&heat[y+1][xx+2]);
            float32x4_t c=vld1q_f32(&heat[y+2][xx+1]), d=vld1q_f32(&heat[y+2][xx+2]);
            a=vaddq_f32(a,vmulq_n_f32(vsubq_f32(b,a),frac));
            c=vaddq_f32(c,vmulq_n_f32(vsubq_f32(d,c),frac));
            float32x4_t cool=vaddq_f32(vmulq_n_f32(vld1q_f32(flow+((j+172)&511)),.005f),vdupq_n_f32(.008f));
            vst1q_f32(&heat[y][x+1],vmaxq_f32(vsubq_f32(vmulq_n_f32(vaddq_f32(a,c),.5f),cool),vdupq_n_f32(0)));
        }
    }
}
static GLuint shader(GLenum type,const char *name) {
    const GLchar *src=asset(name,0); GLuint id=glCreateShader(type);
    glShaderSource(id,1,&src,NULL);glCompileShader(id);free((void*)src);
    GLint ok;glGetShaderiv(id,GL_COMPILE_STATUS,&ok);
    if(!ok){char log[4096];glGetShaderInfoLog(id,sizeof log,NULL,log);die(log);}return id;
}
static GLuint texture(int unit,int width,int height,GLint internal,GLenum format,GLenum type,void *data) {
    GLuint id;glActiveTexture(GL_TEXTURE0+unit);glGenTextures(1,&id);glBindTexture(GL_TEXTURE_2D,id);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D,0,internal,width,height,0,format,type,data);return id;
}
int main(int argc,char **argv) {
    int snapshot=0,background=0,windowed=0,saver=0;
    for(int i=1;i<argc;i++) {
        if(!strcmp(argv[i],"--snapshot")) snapshot=1;
        else if(!strcmp(argv[i],"--background")) snapshot=background=1;
        else if(!strcmp(argv[i],"--windowed")) windowed=1;
        else if(!strcmp(argv[i],"--screensaver")) saver=1;
        else if(!strcmp(argv[i],"--gpu")) {}
        else if(!strcmp(argv[i],"--help")){puts("Jesus Saves native ARM64 | --gpu --windowed --snapshot --background --screensaver\nNative NEON heat and GPU text/fire. The --cpu renderer is available in the Intel build.");return 0;}
        else {fprintf(stderr,"Unsupported option: %s\n",argv[i]);return 2;}
    }
    char executable[PATH_MAX],resolved[PATH_MAX];uint32_t length=sizeof executable;
    if(_NSGetExecutablePath(executable,&length)||!realpath(executable,resolved))die("Cannot find application assets");
    char *slash=strrchr(resolved,'/');if(!slash)die("Invalid executable path");*slash=0;
    if(snprintf(resources,sizeof resources,"%s/../Resources",resolved)>=(int)sizeof resources)die("Path too long");
    turbulence=asset("turbulence.bin",512*256*sizeof(float));
    float seconds=0;const char *timeenv=getenv("FLAME_TIME");if(timeenv){seconds=strtof(timeenv,NULL);if(!isfinite(seconds)||seconds<0)seconds=0;if(seconds>60)seconds=60;}
    for(int i=0;i<240+(snapshot?(int)(seconds*60):0);i++)step();
    if(SDL_Init(SDL_INIT_VIDEO))die(SDL_GetError());
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,4);SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,1);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS,SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    Uint32 flags=SDL_WINDOW_OPENGL|SDL_WINDOW_ALLOW_HIGHDPI;
    flags|=snapshot?SDL_WINDOW_HIDDEN:windowed?SDL_WINDOW_RESIZABLE:SDL_WINDOW_FULLSCREEN_DESKTOP;
    SDL_Window *window=SDL_CreateWindow("JESUS SAVES | Esc to exit",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,1280,720,flags);
    if(!window)die(SDL_GetError());SDL_GLContext context=SDL_GL_CreateContext(window);if(!context)die(SDL_GetError());
    SDL_GL_SetSwapInterval(snapshot?0:1);if(!windowed&&!snapshot)SDL_ShowCursor(SDL_DISABLE);
    GLuint vs=shader(GL_VERTEX_SHADER,"scene.vert"),fs=shader(GL_FRAGMENT_SHADER,"scene.frag"),program=glCreateProgram();
    glAttachShader(program,vs);glAttachShader(program,fs);glLinkProgram(program);glDeleteShader(vs);glDeleteShader(fs);
    GLint ok;glGetProgramiv(program,GL_LINK_STATUS,&ok);if(!ok){char log[4096];glGetProgramInfoLog(program,sizeof log,NULL,log);die(log);}
    glUseProgram(program);glUniform1i(glGetUniformLocation(program,"heaven"),0);glUniform1i(glGetUniformLocation(program,"heatMap"),1);glUniform1i(glGetUniformLocation(program,"lettering"),2);
    GLint clock=glGetUniformLocation(program,"seconds"),bg=glGetUniformLocation(program,"backgroundOnly");
    void *data=asset("background.bgra",W*H*4);GLuint textures[4];textures[0]=texture(0,W,H,GL_RGBA8,GL_BGRA,GL_UNSIGNED_BYTE,data);free(data);
    textures[1]=texture(1,512,160,GL_R32F,GL_RED,GL_FLOAT,NULL);
    data=asset("text-sdf.bin",1536*256*4);textures[2]=texture(2,1536,256,GL_R32F,GL_RED,GL_FLOAT,data);free(data);
    textures[3]=texture(3,W,H,GL_RGBA8,GL_RGBA,GL_UNSIGNED_BYTE,NULL);
    GLuint fbo,vao;glGenFramebuffers(1,&fbo);glBindFramebuffer(GL_FRAMEBUFFER,fbo);glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,textures[3],0);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE)die("4K framebuffer unavailable");glGenVertexArrays(1,&vao);glBindVertexArray(vao);
    int quit=0,frames=0,limit=getenv("FLAME_FRAMES")?atoi(getenv("FLAME_FRAMES")):0;
    Uint64 start=SDL_GetPerformanceCounter();
    do {
        SDL_Event event;while(SDL_PollEvent(&event))if(event.type==SDL_QUIT||(event.type==SDL_WINDOWEVENT&&event.window.event==SDL_WINDOWEVENT_CLOSE)||(event.type==SDL_KEYDOWN&&(saver||event.key.keysym.sym==SDLK_ESCAPE))||(saver&&(event.type==SDL_MOUSEBUTTONDOWN||(event.type==SDL_MOUSEMOTION&&frames>10))))quit=1;
        if(quit)break;
        if(!snapshot){step();seconds=(float)((double)(SDL_GetPerformanceCounter()-start)/SDL_GetPerformanceFrequency());}
        for(int y=0;y<160;y++)memcpy(packed[y],&heat[y][1],512*sizeof(float));
        glActiveTexture(GL_TEXTURE1);glBindTexture(GL_TEXTURE_2D,textures[1]);glTexSubImage2D(GL_TEXTURE_2D,0,0,0,512,160,GL_RED,GL_FLOAT,packed);
        glBindFramebuffer(GL_FRAMEBUFFER,fbo);glViewport(0,0,W,H);glUniform1f(clock,seconds);glUniform1i(bg,background);glDrawArrays(GL_TRIANGLES,0,3);
        if(glGetError()!=GL_NO_ERROR)die("OpenGL rendering failed");
        if(snapshot){
            unsigned char *pixels=malloc(W*H*3);if(!pixels)die("Out of memory");glPixelStorei(GL_PACK_ALIGNMENT,1);glReadPixels(0,0,W,H,GL_RGB,GL_UNSIGNED_BYTE,pixels);
            if(glGetError()!=GL_NO_ERROR)die("Readback failed");FILE *f=fopen("flame.ppm","wb");if(!f)die("Cannot write flame.ppm");fprintf(f,"P6\n%d %d\n255\n",W,H);
            for(int y=H-1;y>=0;y--)if(fwrite(pixels+y*W*3,1,W*3,f)!=W*3)die("Write failed");if(fclose(f))die("Close failed");free(pixels);break;
        }
        int width,height;SDL_GL_GetDrawableSize(window,&width,&height);glBindFramebuffer(GL_READ_FRAMEBUFFER,fbo);glBindFramebuffer(GL_DRAW_FRAMEBUFFER,0);glBlitFramebuffer(0,0,W,H,0,0,width,height,GL_COLOR_BUFFER_BIT,GL_LINEAR);SDL_GL_SwapWindow(window);frames++;
    }while(!limit||frames<limit);
    glDeleteTextures(4,textures);glDeleteFramebuffers(1,&fbo);glDeleteVertexArrays(1,&vao);glDeleteProgram(program);SDL_GL_DeleteContext(context);SDL_DestroyWindow(window);SDL_Quit();free(turbulence);return 0;
}
