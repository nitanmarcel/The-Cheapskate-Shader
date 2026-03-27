#version 330 compatibility

varying vec3 normal;

mat3 tbnNormalTangent(vec3 normal, vec3 tangent) {
    vec3 bitangent = normalize(cross(tangent, normal));
    return mat3(tangent, bitangent, normal);
}

#ifdef VERTEX_SHADER

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec4 tangent;
out vec3 viewSpacePosition;

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position       = ftransform();
    texcoord          = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord           = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor           = gl_Color;

    normal  = gl_NormalMatrix * gl_Normal;
    normal  = mat3(gbufferModelViewInverse) * normal;

    tangent           = vec4(normalize(gl_NormalMatrix * gl_MultiTexCoord1.xyz), 1.0);
    viewSpacePosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3  shadowLightPosition;
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferModelView;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec4 tangent;
in vec3 viewSpacePosition;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    color *= texture(lightmap, lmcoord);
    if (color.a < alphaTestRef) discard;

    vec4 normalData = texture(normals, texcoord);
    vec3 tsNormal;
    tsNormal.xy = normalData.rg * 2.0 - 1.0;
    tsNormal.z  = sqrt(max(1.0 - dot(tsNormal.xy, tsNormal.xy), 0.0));
    tsNormal.y  = -tsNormal.y;
    float ao    = normalData.b;

    vec4  specData             = texture(specular, texcoord);
    float perceptualSmoothness = specData.r;
    float roughness            = pow(1.0 - perceptualSmoothness, 2.0);
    float gRaw                 = specData.g * 255.0;
    float metallic             = gRaw >= 230.0 ? 1.0 : 0.0;
    float emissive             = specData.a < (254.5 / 255.0) ? specData.a : 0.0;

    vec3 worldTangent = mat3(gbufferModelViewInverse) * tangent.xyz;
    mat3 tbn          = tbnNormalTangent(normalize(normal), normalize(worldTangent));
    vec3 detailNormal = normalize(tbn * tsNormal);

	vec3 shadowLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

	float NdotL       = clamp(dot(shadowLightDirection, detailNormal), 0.0, 1.0);
	float lightBrightness = clamp(NdotL, 0.2, 1.0) * ao;

	if (metallic == 1.0) lightBrightness = 0.2 * ao;

	color.rgb *= lightBrightness;

	vec3 viewSpaceLight = normalize(shadowLightPosition);
	vec3 viewDir        = normalize(-viewSpacePosition);
	vec3 halfVec        = normalize(viewSpaceLight + viewDir);
	float NdotH         = max(dot(mat3(gbufferModelView) * detailNormal, halfVec), 0.0);
	float shininess     = pow(2.0, perceptualSmoothness * 10.0);
	float spec          = pow(NdotH, shininess) * (1.0 - roughness);

	vec3 specColor = metallic == 1.0
		? texture(gtexture, texcoord).rgb * glcolor.rgb * spec
		: vec3(spec * 0.04);

	color.rgb += specColor;

	color.rgb += texture(gtexture, texcoord).rgb * glcolor.rgb * emissive;
}
#endif // FRAGMENT_SHADER