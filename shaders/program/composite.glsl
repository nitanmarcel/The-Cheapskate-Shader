#version 330 compatibility

#include "/lib/utils.glsl"
#include "/lib/settings.glsl"

varying vec2 texcoord;

#ifdef VERTEX_SHADER

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
uniform sampler2D colortex0;
uniform sampler2D colortex1;

uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);

	#ifdef BLOOM
		vec3 bloomSource = texture(colortex0, texcoord).rgb;

		float luminance = dot(bloomSource, vec3(0.2126, 0.7152, 0.0722));
		float threshold = 0.85; 
		vec3 brightParts = bloomSource * smoothstep(threshold, threshold + 0.1, luminance);

		vec3 blur = vec3(0.0);
		float blurScale = 1.5;
		vec2 res = vec2(viewWidth, viewHeight);

		blur += brightParts * 0.22;
		blur += texture(colortex0, texcoord + vec2(1.33 * blurScale / res.x, 0.0)).rgb * 0.35;
		blur += texture(colortex0, texcoord - vec2(1.33 * blurScale / res.x, 0.0)).rgb * 0.35;
		blur += texture(colortex0, texcoord + vec2(0.0, 1.33 * blurScale / res.y)).rgb * 0.35;
		blur += texture(colortex0, texcoord - vec2(0.0, 1.33 * blurScale / res.y)).rgb * 0.35;

		color.rgb += (blur * BLOOM_STRENGTH); 
	#endif
	
	vec3 hsv = rgb2hsv(color.rgb);
	hsv.y *= SATURATION;
	color.rgb = hsv2rgb(hsv);

	color.rgb = color.rgb * EXPOSURE;
}
#endif // FRAGMENT_SHADER
