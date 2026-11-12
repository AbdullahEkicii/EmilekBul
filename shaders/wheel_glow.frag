#version 460 core
#include <flutter/runtime_effect.glsl>

// Soft animated radial glow behind the lucky wheel.
// uTime is expected in [0, 2*PI) and loops seamlessly because every
// time-dependent term uses an integer frequency.
uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;

out vec4 fragColor;

const vec3 PURPLE = vec3(0.545, 0.361, 0.965);
const vec3 AMBER = vec3(1.0, 0.624, 0.263);

void main() {
    vec2 frag = FlutterFragCoord().xy;
    // normalise by the smaller side so the glow stays circular
    float side = max(min(uSize.x, uSize.y), 1.0);
    vec2 uv = (frag - 0.5 * uSize) / (0.5 * side);

    float d = length(uv);                // 0 at centre, ~1 at the inscribed edge
    float angle = atan(uv.y, uv.x);

    float pulse = 0.5 + 0.5 * sin(uTime * 2.0);
    float wobble = 0.035 * sin(uTime * 3.0 + angle * 3.0);
    float ringRadius = 0.62 + 0.04 * pulse + wobble;

    float core = 1.0 - smoothstep(0.0, 0.7, d);
    float ring = exp(-pow((d - ringRadius) * 7.0, 2.0));
    float glow = clamp(core * 0.35 + ring * 0.65, 0.0, 1.0);

    // fade out towards the outer border so the glow never hard-clips
    glow *= 1.0 - smoothstep(0.85, 1.0, d);

    float mixT = 0.5 + 0.5 * sin(uTime + angle * 2.0);
    vec3 col = mix(PURPLE, AMBER, mixT);

    float alpha = glow * uIntensity * (0.6 + 0.25 * pulse);
    // Flutter expects premultiplied alpha output
    fragColor = vec4(col * alpha, alpha);
}
