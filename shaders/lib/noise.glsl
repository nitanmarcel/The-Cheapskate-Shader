float random(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 151.7182))) * 43758.5453);
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    // Hash coordinates
    float a = random(i);
    float b = random(i + vec3(1.0, 0.0, 0.0));
    float c = random(i + vec3(0.0, 1.0, 0.0));
    float d = random(i + vec3(1.0, 1.0, 0.0));
    float e = random(i + vec3(0.0, 0.0, 1.0));
    float f1 = random(i + vec3(1.0, 0.0, 1.0));
    float g = random(i + vec3(0.0, 1.0, 1.0));
    float h = random(i + vec3(1.0, 1.0, 1.0));

    // Interpolate between the values
    vec3 u = smoothstep(0.0, 1.0, f);
    float x0 = mix(a, b, u.x);
    float x1 = mix(c, d, u.x);
    float y0 = mix(x0, x1, u.y);
    
    x0 = mix(e, f1, u.x);
    x1 = mix(g, h, u.x);
    float y1 = mix(x0, x1, u.y);
    
    return mix(y0, y1, u.z);
}

float worleyNoise(vec3 p) {
    vec3 id = floor(p);
    vec3 fd = fract(p);
    
    float minDist = 1.0;
    
    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec3 offset = vec3(x, y, z);
                vec3 cellId = id + offset;
                vec3 cellCenter = cellId + random(cellId) * 0.8; // Random position within cell
                minDist = min(minDist, length(p - cellCenter));
            }
        }
    }
    
    return 1.0 - minDist;
}