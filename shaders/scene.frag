// SPDX-License-Identifier: GPL-3.0-only
#version 330 core
in vec2 uv;
out vec4 fragColor;
uniform sampler2D heaven, heatMap, lettering;
uniform float seconds;
uniform int backgroundOnly;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1),f.x),f.y);}
float fbm(vec2 p){float f=0.,a=.5;for(int i=0;i<5;i++){f+=a*noise(p);p=mat2(1.65,-1.12,1.12,1.65)*p+3.71;a*=.5;}return f;}
float shape(vec3 p){
    float d=texture(lettering,(p.xy+vec2(192,32))/vec2(384,64)).r;
    d=max(d,max(abs(p.x)-192.,abs(p.y)-32.));
    float z=abs(p.z)-7.;
    return max(max(d,z),(d+z+2.)*.70710678);
}
vec3 gold(vec3 p,mat3 localToScreen,vec2 center){
    const float e=.3;
    vec3 n=normalize(vec3(shape(p+vec3(e,0,0))-shape(p-vec3(e,0,0)),shape(p+vec3(0,e,0))-shape(p-vec3(0,e,0)),shape(p+vec3(0,0,e))-shape(p-vec3(0,0,e))));
    n=localToScreen*n;
    vec3 reflected=reflect(vec3(0,0,1),n);
    vec2 env=vec2(.5+.45*reflected.x,.28-.28*reflected.y);
    vec3 sky=texture(heaven,clamp(env,0.,1.)).rgb;
    float stripe=reflected.y+.18*reflected.x+.28+p.y*.012+p.x*.0015;
    float spec=1./(1.+95.*stripe*stripe);
    float light=.28+.40*max(dot(n,normalize(vec3(-.2,-.5,-1))),0.);
    vec3 metal=vec3(1.,.69,.15)*(light+.48*dot(sky,vec3(.3,.5,.2)))+vec3(1.,.92,.6)*spec*.85;
    float fire=texture(heatMap,vec2(clamp(center.x/3840.+reflected.x*.2,0.,1.),.93)).r;
    metal+=vec3(.14,.055,.006)*fire*max(reflected.y,0.);
    return metal;
}
void main(){
    vec2 st=vec2(uv.x,1.-uv.y); // top-down, matching CPU heat/font/image data
    vec3 color=texture(heaven,st).rgb;
    if(backgroundOnly!=0){fragColor=vec4(color,1);return;}
    if(st.y>1200./2160.){
        vec2 f=vec2(st.x,(st.y-1200./2160.)/(960./2160.));
        vec2 q=f*vec2(37.,11.);q.y+=seconds*2.2;
        float warp=fbm(q*.51+vec2(0,seconds*.18));
        float wisps=fbm(q+vec2(2.4*warp,0));
        float micro=fbm(q*3.2+vec2(seconds*.17,0));
        vec2 sampleUV=f+vec2((warp-.5)*.018,0);
        float h=texture(heatMap,sampleUV).r;
        // Evolving pockets and folded thin flame sheets, not opaque solid tongues.
        h*=clamp((wisps-.16)*2.1,0.,1.5);
        h*=.72+.55*micro;
        vec3 flame=vec3(pow(clamp(h*3.1,0.,1.),1.45),pow(clamp(h*1.7,0.,1.),2.),pow(clamp(h,0.,1.),3.)*.65);
        flame*=smoothstep(0.,.13,f.y);
        color+=flame;
    }
    float yaw=seconds*.43-.38,pitch=sin(seconds*.67)*.40-.20;
    float cy=cos(yaw),sy=sin(yaw),cp=cos(pitch),sp=sin(pitch);
    mat3 toLocal=mat3(vec3(cy,sy*sp,sy*cp),vec3(0,cp,-sp),vec3(-sy,cy*sp,cy*cp));
    vec2 center=vec2(1920.+750.*sin(seconds*.29),600.+354.*sin(seconds*.41));
    vec2 pos=st*vec2(3840,2160)-center;
    vec2 bounds=vec2(dot(abs(toLocal[0]),vec3(192,32,7)),dot(abs(toLocal[1]),vec3(192,32,7)))*6.6+3.;
    if(all(lessThan(abs(pos),bounds)) && st.y<1200./2160.){
        vec3 p=toLocal*vec3(pos/6.6,-205.),dir=toLocal[2];float travel=0.;
        for(int i=0;i<110;i++){
            float d=shape(p);
            if(d<.09){color=gold(p,transpose(toLocal),center);break;}
            d*=.72;travel+=d;if(travel>410.)break;p+=dir*d;
        }
    }
    fragColor=vec4(clamp(color,0.,1.),1.);
}
