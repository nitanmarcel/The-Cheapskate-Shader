// shadow.glsl
#version 330 compatibility
varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#ifdef VERTEX_SHADER
#include "../lib/distort.glsl"

void main() {
    texcoord        = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord         = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor         = gl_Color;
    gl_Position     = ftransform();
    gl_Position.xyz = distort(gl_Position.xyz);
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
uniform sampler2D gtexture;
uniform float alphaTestRef = 0.1;

layout(location = 0) out vec4 color;

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    if (color.a < alphaTestRef) discard;
}
#endif // FRAGMENT_SHADER