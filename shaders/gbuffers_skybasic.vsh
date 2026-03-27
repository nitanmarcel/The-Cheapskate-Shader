#version 330 compatibility

#define DISABLE_INDIRECT_LIGHTING
out vec4 glcolor;

void main() {
	gl_Position = ftransform();
	glcolor = gl_Color;
}
