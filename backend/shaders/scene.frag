#version 450
layout(location=0) in vec2 vUv;
layout(location=1) in vec4 vColor;
layout(location=2) in vec4 vDetail;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform Frame { mat4 matrix; vec4 viewport; } frame;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float fbm(vec2 p) { return noise(p)*0.57+noise(p*2.07+17.0)*0.28+noise(p*4.19+31.0)*0.15; }
void main() {
    vec2 p=vUv*2.0-1.0;
    if(vDetail.x>1.5 && vDetail.x<2.5) {
        float n=fbm(p*2.7+vec2(vDetail.y,vDetail.z*0.23));
        float silhouette=1.0-smoothstep(0.28,1.0,length(p)+(n-0.5)*0.24);
        float density=silhouette*smoothstep(0.21,0.79,n)*vColor.a;
        fragColor=vec4(vColor.rgb*density,density);
    } else if(vDetail.x>2.5) {
        float r=length(p);
        float light=exp(-r*8.0)*(1.0-smoothstep(0.65,1.0,r));
        fragColor=vec4(vColor.rgb*light,clamp(light*vColor.a,0.0,1.0));
    } else if(vDetail.x>0.5) {
        float d=abs(p.y);
        float edge=exp(-d*d*7.0)*(1.0-smoothstep(0.65,1.0,d));
        fragColor=vec4(vColor.rgb*edge,clamp(edge*vColor.a,0.0,1.0));
    } else {
        float r=length(p);
        float halo=exp(-r*r*7.0)*(1.0-smoothstep(0.7,1.0,r));
        float core=exp(-r*r*65.0);
        float energy=max(vColor.r,max(vColor.g,vColor.b));
        // A pale-hot center inside the star's own colored halo. A fixed golden
        // core would contaminate blue, green, and violet sparks and their bloom.
        vec3 coreColor=mix(vColor.rgb/max(energy,0.00001),vec3(1.0),0.52);
        vec3 light=vColor.rgb*halo+coreColor*energy*core*1.5;
        fragColor=vec4(light,clamp((halo+core)*vColor.a,0.0,1.0));
    }
}
