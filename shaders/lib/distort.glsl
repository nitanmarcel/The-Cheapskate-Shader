const int   shadowMapResolution = 2048;  // Shadow map resolution [512 1024 2048 4096 8192]

#define SHADOW_DISTORT_FACTOR 0.10
#define SHADOW_BIAS           0.05
#define SHADOW_BRIGHTNESS     0.20

vec3 distort(vec3 pos) {
    float factor = length(pos.xy) + SHADOW_DISTORT_FACTOR;
    return vec3(pos.xy / factor, pos.z * 0.5);
}

float computeBias(vec3 pos) {
    float numerator = length(pos.xy) + SHADOW_DISTORT_FACTOR;
    numerator *= numerator;
    return SHADOW_BIAS / shadowMapResolution * numerator / SHADOW_DISTORT_FACTOR;
}