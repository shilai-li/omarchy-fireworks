#version 450
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 fragColor;
layout(binding=1) uniform sampler2D source;
layout(binding=2) uniform sampler2D glow;
layout(binding=3) uniform sampler2D wideGlow;
layout(std140,binding=0) uniform Post { mat4 matrix; vec4 params; vec4 controls; } post;
void main() {
    int mode=int(post.params.z+0.5);
    vec2 delta=post.params.xy;
    if(mode==0 || mode==3) {
        vec4 c=(texture(source,vUv+delta*vec2(-0.5,-0.5))+
                texture(source,vUv+delta*vec2(0.5,-0.5))+
                texture(source,vUv+delta*vec2(-0.5,0.5))+
                texture(source,vUv+delta*vec2(0.5,0.5)))*0.25;
        float brightness=max(c.r,max(c.g,c.b));
        float contribution=mode==0 ? smoothstep(0.05,0.9,brightness) : 1.0;
        fragColor=vec4(c.rgb*contribution,0.0);
    } else if(mode==1) {
        vec3 c=texture(source,vUv).rgb*0.227027;
        c+=(texture(source,vUv+delta*1.384615).rgb+texture(source,vUv-delta*1.384615).rgb)*0.316216;
        c+=(texture(source,vUv+delta*3.230769).rgb+texture(source,vUv-delta*3.230769).rgb)*0.070270;
        fragColor=vec4(c,0.0);
    } else {
        vec4 scene=texture(source,vUv);
        vec3 radiance=scene.rgb+post.controls.y*(texture(glow,vUv).rgb*0.65+texture(wideGlow,vUv).rgb*0.85);
        // Apply the shoulder to intensity, not separately to RGB channels:
        // bright colored trails keep their hue instead of clipping to white.
        float peak=max(radiance.r,max(radiance.g,radiance.b));
        vec3 mapped=radiance*((1.0-exp(-peak*post.controls.x))/max(peak,0.00001));
        // SDR premultiplied output: transparent bloom must not leave dark boxes.
        float alpha=clamp(max(scene.a,max(mapped.r,max(mapped.g,mapped.b))),0.0,1.0);
        fragColor=vec4(mapped,alpha);
    }
}
