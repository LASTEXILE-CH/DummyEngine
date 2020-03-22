R"(#version 310 es

#ifdef GL_ES
    precision mediump float;
#endif

)" __ADDITIONAL_DEFINES_STR__ R"(

#ifdef TRANSPARENT_PERM
layout(binding = )" AS_STR(REN_ALPHATEST_TEX_SLOT) R"() uniform sampler2D alphatest_texture;

in vec2 aVertexUVs1_;
#endif

#ifdef OUTPUT_VELOCITY
in vec3 aVertexCSCurr_;
in vec3 aVertexCSPrev_;

out vec2 outVelocity;
#endif

void main() {
#ifdef TRANSPARENT_PERM
    float alpha = texture(alphatest_texture, aVertexUVs1_).a;
    if (alpha < 0.5) discard;
#endif

#ifdef OUTPUT_VELOCITY
    vec2 curr = aVertexCSCurr_.xy / aVertexCSCurr_.z;
    vec2 prev = aVertexCSPrev_.xy / aVertexCSPrev_.z;
    outVelocity = curr - prev;
#endif
}
)"
