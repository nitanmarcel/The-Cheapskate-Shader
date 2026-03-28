#version 330 compatibility

#include "/lib/utils.glsl"
#include "/lib/sky/atmosphere.glsl"

varying vec2 texcoord;

#ifdef VERTEX_SHADER
void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float far;
uniform float fogStart;
uniform float fogEnd;
uniform vec3 fogColor;

#ifdef DISTANT_HORIZONS
uniform float dhFarPlane;
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition; 
uniform float viewWidth;
uniform float viewHeight;
uniform vec3 sunPosition;
uniform float rainStrength;

layout(location = 0) out vec4 color;

const float CLOUD_BASE = 320.0; 
const float CLOUD_THICK = 90.0;      
const int STEPS = 24;      
const float COVERAGE = 0.5;
const float SOFTNESS = 0.25;      

float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 / (4.0 * 3.14159)) * ((1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

float getDensity(vec3 p, bool highDetail) {
    if (p.y < CLOUD_BASE || p.y > (CLOUD_BASE + CLOUD_THICK)) return 0.0;

    float windSpeed = 0.02;
    vec2 windOffset = vec2(frameTimeCounter * windSpeed, frameTimeCounter * windSpeed * 0.2);

    float heightAlpha = (p.y - CLOUD_BASE) / CLOUD_THICK;
    float verticalShape = smoothstep(0.0, 0.2, heightAlpha) * smoothstep(1.0, 0.5, heightAlpha);

    vec3 s = vec3((p.xz * 0.001) + windOffset, frameTimeCounter * 0.0006);
    float n = noise(s);

    float coverage = clamp(rainStrength, 0.5, 1.0);
    
    float baseDensity = n * verticalShape - (1.0 - coverage);
    if (baseDensity <= 0.0) return 0.0;

    if (highDetail) {
        float detail = noise(s * 4.5) * 0.2 + noise(s * 9.0) * 0.05;
        n = n * 0.75 + detail;
        float bite = noise(vec3(p.xz * 0.02, frameTimeCounter * 0.002));
        n -= bite * (1.0 - n) * 0.35; 
    }
    
    float density = max(0.0, n * verticalShape - (1.0 - coverage));
    return smoothstep(0.0, SOFTNESS, density);
}

void main() {
    color = texture(colortex0, texcoord);
    
    float depth = texture(depthtex0, texcoord).r;
    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), depth);
    vec4 viewPos4 = gbufferProjectionInverse * vec4(screenPos * 2.0 - 1.0, 1.0);
    vec3 viewPos = viewPos4.xyz / viewPos4.w;
    float dist = length(viewPos) / far;

    #ifdef DISTANT_HORIZONS
    float dhDepth = texture(dhDepthTex0, texcoord).r;
    if (dhDepth < 1.0) {
        vec4 dhViewPos4 = dhProjectionInverse * vec4(vec3(screenPos.xy, dhDepth) * 2.0 - 1.0, 1.0);
        float dhDist = length(dhViewPos4.xyz / dhViewPos4.w) / dhFarPlane;
        
        if (depth >= 1.0 || dhDist < dist) {
            dist = dhDist;
        }
    }
    #endif
    
    vec3 worldRay = normalize(mat3(gbufferModelViewInverse) * viewPos);
    vec3 pPos = cameraPosition; 

    float t1 = (CLOUD_BASE - pPos.y) / worldRay.y;
    float t2 = (CLOUD_BASE + CLOUD_THICK - pPos.y) / worldRay.y;
    float tMin = min(t1, t2);
    float tMax = max(t1, t2);

    float startDist = max(0.0, tMin);
    float endDist = (depth < 1.0) ? min(tMax, dist) : tMax;
    
    #ifdef DISTANT_HORIZONS
    if (dhDepth < 1.0) endDist = min(tMax, dist);
    #endif

    float transmittance = 1.0;
    vec3 scatteredLight = vec3(0.0);

    if (endDist > startDist && tMax > 0.0) {
        vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
        vec3 sunCol = calculateSkyColor(sunDir, sunDir) * 2.0; 
        vec3 skyAmbient = calculateSkyColor(vec3(0.0, 1.0, 0.0), sunDir);
        vec3 hazeExtinction = calculateExtinction(worldRay, sunDir);

        float dither = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
        float stepSize = (endDist - startDist) / float(STEPS);

        for(int i = 0; i < STEPS; i++) {
            float rayOffset = (float(i) + dither) * stepSize;
            vec3 p = pPos + worldRay * (startDist + rayOffset);
            float d = getDensity(p, true);

            if (d > 0.01) {
                float lightDensity = 0.0;
                float shadowStep = 6.0; 
                for(int j = 1; j <= 4; j++) { 
                    vec3 shadowP = p + sunDir * (float(j) * shadowStep);
                    lightDensity += getDensity(shadowP, false);
                }

                float absorption = 0.3; 
                float beer = exp(-lightDensity * absorption);
                float multiScatter = exp(-lightDensity * (absorption * 0.25)) * 0.4;
                float shadow = beer + multiScatter;

                float cosTheta = dot(worldRay, sunDir);
                float forward = hgPhase(cosTheta, 0.7);  
                float backward = hgPhase(cosTheta, -0.1); 
                float phase = mix(backward, forward, 0.5);

                float hf = (p.y - CLOUD_BASE) / CLOUD_THICK;
                vec3 ambient = mix(skyAmbient * 0.4, skyAmbient * 1.1, hf); 
                
                vec3 lightIntensity = sunCol * shadow * phase * 4.0;
                vec3 stepColor = ambient + lightIntensity;
                
                stepColor = 1.0 - exp(-stepColor * 1.4);  
                float alpha = 1.0 - exp(-d * 0.3);
                
                scatteredLight += stepColor * hazeExtinction * transmittance * alpha;
                transmittance *= (1.0 - alpha);

                if (transmittance < 0.01) break;
            }
        }
    }

    color.rgb = color.rgb * transmittance + scatteredLight;
    float fogFactor = clamp((dist - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
    color.rgb = mix(color.rgb, fogColor, fogFactor);
}
#endif