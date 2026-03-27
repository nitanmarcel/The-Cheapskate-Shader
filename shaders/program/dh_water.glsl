
#version 330 compatibility

#ifdef VERTEX_SHADER

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D depthtex0;

uniform float viewHeight;
uniform float viewWidth;

uniform float alphaTestRef = 0.1;


in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	color *= texture(lightmap, lmcoord);
	if (color.a < alphaTestRef) {
		discard;
	}

    vec2 dhTextcoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float depth = texture(depthtex0, dhTextcoord).r;
    if (depth != 1.0) {
        discard;
    }
}
#endif // FRAGMENT_SHADER
