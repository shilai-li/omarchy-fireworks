#version 450
layout(location=0) in vec2 position;
layout(location=1) in vec2 uv;
layout(location=2) in vec4 color;
layout(location=3) in vec4 detail;
layout(location=0) out vec2 vUv;
layout(location=1) out vec4 vColor;
layout(location=2) out vec4 vDetail;
layout(std140,binding=0) uniform Frame { mat4 matrix; vec4 viewport; } frame;
void main() {
    vUv=uv; vColor=color; vDetail=detail;
    gl_Position=frame.matrix*vec4(position,0.0,1.0);
}
