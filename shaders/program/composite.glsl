#version 330 compatibility

#define BLOOM // Enables bloom.
#define BLOOM_STRENGTH 0.12 // Bloom Birghtness [0.027 0.036 0.045 0.054 0.063 0.072 0.081 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.21 0.23 0.25 0.28 0.32 10.00]0.12

#ifdef VERTEX_SHADER

out vec2 texcoord;



void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
uniform sampler2D colortex0;
uniform sampler2D colortex1;

in vec2 texcoord;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);

	vec3 blur = texture2D(colortex1, texcoord / 4.0).rgb;
	blur = clamp(blur, vec3(0.0), vec3(1.0));
	blur *= blur;

	float luminance = dot(blur, vec3(0.2126, 0.7152, 0.0722));
	float threshold = 0.7;
	float softThreshold = 0.1;

	float brightness = smoothstep(threshold - softThreshold, threshold + softThreshold, luminance);
	blur *= brightness;

	float bloomStrength = BLOOM_STRENGTH * 0.08;
	color.rgb = mix(color.rgb, blur, bloomStrength);
}
#endif // FRAGMENT_SHADER
