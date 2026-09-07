#version 450
layout(location=0) out vec2 vUv;
layout(std140,binding=0) uniform Post { mat4 matrix; vec4 params; vec4 controls; } post;
void main() {
    vec2 uv=vec2((gl_VertexIndex<<1)&2,gl_VertexIndex&2);
    vUv=vec2(uv.x,post.params.w>0.5 ? 1.0-uv.y : uv.y);
    gl_Position=post.matrix*vec4(uv*2.0-1.0,0.0,1.0);
}
