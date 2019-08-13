R"(
#version 310 es
#extension GL_ARB_texture_multisample : enable

#ifdef GL_ES
    precision mediump float;
#endif

layout(binding = )" AS_STR(REN_BASE_TEX_SLOT) R"() uniform mediump sampler2DMS s_texture;

in vec2 aVertexUVs_;

out vec4 outColor;

void main() {
    outColor = 0.25 * (texelFetch(s_texture, ivec2(aVertexUVs_), 0) +
                       texelFetch(s_texture, ivec2(aVertexUVs_), 1) +
                       texelFetch(s_texture, ivec2(aVertexUVs_), 2) +
                       texelFetch(s_texture, ivec2(aVertexUVs_), 3));
}
)"