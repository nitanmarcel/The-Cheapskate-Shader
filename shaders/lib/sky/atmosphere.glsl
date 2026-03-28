#include "/lib/noise.glsl"

#define SUN_INTENSITY 1.0

uniform int renderStage;
uniform int worldTime;

uniform float frameTimeCounter;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

// Faster atmosphere calculation
// Copyright (c) 2019 Silvio Henrique Ferreira (MIT)
// https://github.com/shff/opengl_sky

const float BR = 0.0002;
const float BM = 0.0001;
const float G = 0.9200;
const vec3 NITROGEN = vec3(0.650, 0.570, 0.475);

vec3 getKr() {
    return BR / pow(NITROGEN, vec3(4.0));
}

vec3 getKm() {
    return BM / pow(NITROGEN, vec3(0.84));
}

float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

vec3 getStars(vec3 pos) {
    vec3 nPos = normalize(pos);
    vec3 starPos = floor(nPos * 300.0) / 300.0;

    float stars_threshold = 5000.0;
    float stars_exposure = 10.0;

    float stars_brightness = hash(starPos * 100.0 + vec3(frameTimeCounter * 0.0005));

    float stars = pow(clamp(hash(starPos * 200.0), 0.0, 1.0), stars_threshold) * stars_brightness * stars_exposure;
    
    vec3 color = mix(
        vec3(1.0, 1.0, 1.3),
        vec3(1.3, 1.0, 0.7),
        hash(starPos * 50.0 + vec3(worldTime * 0.02))
    );

    return vec3(stars) * color * 0.5;
}

vec3 calculateExtinction(vec3 viewDir, vec3 sunDir) {
    vec3 Kr = getKr();
    
    vec3 day_extinction = exp(-exp(-((viewDir.y + sunDir.y * 4.0) * (exp(-viewDir.y * 16.0) + 0.1) / 80.0) / BR) * 
                          (exp(-viewDir.y * 16.0) + 0.1) * Kr / BR) * 
                          exp(-viewDir.y * exp(-viewDir.y * 8.0) * 4.0) * 
                          exp(-viewDir.y * 2.0) * 4.0;
    
    vec3 night_extinction = vec3(0.05, 0.05, 0.1) * 0.5;
    
    float dayNightMix;
    
    if (sunDir.y > 0.1) {
        dayNightMix = 1.0;
    } else if (sunDir.y > -0.1) {
        dayNightMix = (sunDir.y + 0.1) / 0.2;
        
        if (dayNightMix < 0.5) {
            day_extinction *= mix(vec3(1.0), vec3(1.4, 0.9, 0.6), 1.0 - 2.0 * dayNightMix);
        }
    } else {
        dayNightMix = 0.0;
    }
    day_extinction *= 0.6;
    return mix(night_extinction, day_extinction, dayNightMix);
}

vec3 calculateSkyColor(vec3 pos, vec3 sun) {
    vec3 viewDir = normalize(pos);
    vec3 sunDir = normalize(sun);
    
    vec3 Kr = getKr();
    vec3 Km = getKm();
    
    float sunViewDot = dot(viewDir, sunDir);
    
    float mu = sunViewDot;
    
    float rayleigh = 3.0 / (8.0 * 3.14) * (1.0 + mu * mu);
    
    vec3 mie = (Kr + Km * (1.0 - G * G) / (2.0 + G * G) / pow(1.0 + G * G - 2.0 * G * mu, 1.5)) / (BR + BM);

    vec3 extinction = calculateExtinction(viewDir, sunDir);
    
    vec3 skyColor = rayleigh * mie * extinction;
    
    if (sunDir.y < -0.1) {
        float nightDarkness = smoothstep(-0.1, -0.4, sunDir.y);
        vec3 nightColor = vec3(0.05, 0.05, 0.1) * 0.5;
        skyColor = mix(skyColor, nightColor, nightDarkness);
    }

    if (renderStage == MC_RENDER_STAGE_SKY) {
        vec3 stars = getStars(viewDir);
        float starVisibility = smoothstep(0.05, -0.05, sunDir.y);
        skyColor = mix(skyColor, max(skyColor, stars), starVisibility);
    } 
    
    float hardness = 2000.0;
    float sunDiscThreshold = 0.99965;
    
    float disc = pow(smoothstep(0.0, 1.0, saturate((sunViewDot - sunDiscThreshold) * hardness)), 2.0);
    
    float visibility = smoothstep(0.0, 1.0, saturate(viewDir.y * 30.0));
    disc *= visibility;
    
    vec3 sunColor = vec3(1.0, 0.98, 0.92) * SUN_INTENSITY;
    
    float sunAboveHorizon = smoothstep(-0.025, 0.025, sunDir.y);
    
    // Apply sun disc with intensity factor
    vec3 sunDisc = disc * sunColor * sunAboveHorizon;
    
    // Apply sun glow with intensity factor 
    float sunGlow = pow(max(0.0, visibility / (-sunViewDot * 250.0 + 250.01) - 0.1), 2.0) * 0.0002 * 100.0;
    vec3 sunGlowColor = vec3(1.0, 0.7, 0.3) * SUN_INTENSITY;
    
    // Add sun components to sky color
    skyColor += sunDisc;
    skyColor += sunGlow * sunGlowColor * sunAboveHorizon;
    
    // Modified tone mapping to allow more brightness from high SUN_INTENSITY values
    // Using a modified version that allows more brightness when SUN_INTENSITY is high
    float tonemapFactor = max(1.0, SUN_INTENSITY * 0.05);
    skyColor = skyColor / (1.0 + skyColor * (0.5 / tonemapFactor));
    
    return skyColor;
}
