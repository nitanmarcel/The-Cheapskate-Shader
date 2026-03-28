#version 330 compatibility

#include "/lib/sky/atmosphere.glsl"
#include "/lib/utils.glsl"

varying vec4 glcolor;

#ifdef VERTEX_SHADER

void main() {
	gl_Position = ftransform();
	glcolor = gl_Color;
}

#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER

uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform vec3 sunPosition;
uniform vec3 cameraPosition;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0);
    vec3 viewPos = screenToView(screenPos, gbufferProjectionInverse);

    vec3 viewDir = normalize(viewPos);
	vec3 worldViewDir = mat3(gbufferModelViewInverse) * viewDir;
	vec3 worldSunDir = mat3(gbufferModelViewInverse) * sunPosition;

	vec3 newSkyColor = calculateSkyColor(worldViewDir, worldSunDir);

	color.rgb = newSkyColor;
}
#endif // FRAGMENT_SHADER