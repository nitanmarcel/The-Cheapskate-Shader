#version 330 compatibility
varying vec3 normal;

#include "../lib/distort.glsl"

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
out vec4 shadowSpacePosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

void main() {
    gl_Position       = ftransform();
    texcoord          = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord           = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor           = gl_Color;
    normal            = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
    tangent           = vec4(normalize(gl_NormalMatrix * gl_MultiTexCoord1.xyz), 1.0);
    viewSpacePosition = (gl_ModelViewMatrix * gl_Vertex).xyz;

    vec4 worldPos           = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
    shadowSpacePosition     = shadowProjection * (shadowModelView * worldPos);
    shadowSpacePosition.xyz = distort(shadowSpacePosition.xyz);
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
uniform sampler2D       lightmap;
uniform sampler2D       gtexture;
uniform sampler2D       normals;
uniform sampler2D       specular;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform vec3  shadowLightPosition;
uniform mat4  gbufferModelViewInverse;
uniform mat4  gbufferModelView;
uniform mat4  shadowModelView;
uniform mat4  shadowProjection;
uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec4 tangent;
in vec3 viewSpacePosition;
in vec4 shadowSpacePosition;

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
    float metallic             = specData.g * 255.0 >= 230.0 ? 1.0 : 0.0;
    float emissive             = specData.a < (254.5 / 255.0) ? specData.a : 0.0;

    vec3 worldTangent = mat3(gbufferModelViewInverse) * tangent.xyz;
    mat3 tbn          = tbnNormalTangent(normalize(normal), normalize(worldTangent));
    vec3 detailNormal = normalize(tbn * tsNormal);

    vec3  shadowLightDirection = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float NdotL                = clamp(dot(shadowLightDirection, detailNormal), 0.0, 1.0);

    float shadow = 0.0;
    if (NdotL > 0.0) {
        vec3 shadowCoord = shadowSpacePosition.xyz / shadowSpacePosition.w;
        shadowCoord      = shadowCoord * 0.5 + 0.5;

        #ifdef NORMAL_BIAS
            shadowCoord -= normalize(mat3(shadowProjection * shadowModelView) * detailNormal)
                           * computeBias(shadowSpacePosition.xyz) * 0.1;
        #else
            shadowCoord.z -= computeBias(shadowSpacePosition.xyz);
        #endif

        if (shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 &&
            shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0) {

            float bias = computeBias(shadowSpacePosition.xyz);

            float depthOpaque      = texture(shadowtex1, shadowCoord.xy).r;
            float depthTranslucent = texture(shadowtex0, shadowCoord.xy).r;

            float shadowOpaque      = step(shadowCoord.z - bias, depthOpaque);
            float shadowTranslucent = step(shadowCoord.z - bias, depthTranslucent);

            if (shadowOpaque < 1.0) {
                shadow = shadowOpaque;
            } else if (shadowTranslucent < 1.0) {
                vec3 shadowTint = texture(shadowcolor0, shadowCoord.xy).rgb;
                shadow = shadowTranslucent * dot(shadowTint, vec3(0.333));
            } else {
                shadow = 1.0;
            }
        }
    }

    float lightBrightness;
    if (metallic == 1.0) {
        lightBrightness = SHADOW_BRIGHTNESS * ao;
    } else {
        lightBrightness = max(NdotL * shadow, SHADOW_BRIGHTNESS) * ao;
    }
    color.rgb *= lightBrightness;

    vec3  viewSpaceLight = normalize(shadowLightPosition);
    vec3  viewDir        = normalize(-viewSpacePosition);
    vec3  halfVec        = normalize(viewSpaceLight + viewDir);
    float NdotH          = max(dot(mat3(gbufferModelView) * detailNormal, halfVec), 0.0);
    float shininess      = pow(2.0, perceptualSmoothness * 10.0);
    float spec           = pow(NdotH, shininess) * (1.0 - roughness);

    vec3 specColor = metallic == 1.0
        ? texture(gtexture, texcoord).rgb * glcolor.rgb * spec
        : vec3(spec * 0.04);
    color.rgb += specColor * shadow;

    color.rgb += texture(gtexture, texcoord).rgb * glcolor.rgb * emissive;
}
#endif // FRAGMENT_SHADER