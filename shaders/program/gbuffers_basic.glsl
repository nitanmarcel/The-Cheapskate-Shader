#version 330 compatibility

varying vec3 normal;

#ifdef VERTEX_SHADER

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

uniform mat4 gbufferModelViewInverse;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;


	normal = gl_NormalMatrix * gl_Normal;
	normal = mat3(gbufferModelViewInverse) * normal;	
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;

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

	#ifndef DISABLE_INDIRECT_LIGHTING
		vec3 shadowLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
		float lightBrightness = clamp(dot(shadowLightDirection, normal), 0.2,1.0);
		color *= lightBrightness;
	#endif
	
}
#endif // FRAGMENT_SHADER
