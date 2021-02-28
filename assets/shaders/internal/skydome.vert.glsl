#version 310 es

/*
UNIFORM_BLOCKS
    SharedDataBlock : $ubSharedDataLoc
*/

#include "_vs_common.glsl"

#if defined(VULKAN) || defined(GL_SPIRV)
layout (binding = REN_UB_SHARED_DATA_LOC, std140)
#else
layout (std140)
#endif
uniform SharedDataBlock {
    SharedData shrd_data;
};

layout(location = REN_VTX_POS_LOC) in vec3 aVertexPosition;

layout(location = REN_U_M_MATRIX_LOC) uniform mat4 uMMatrix;

#if defined(VULKAN) || defined(GL_SPIRV)
layout(location = 0) out vec3 aVertexPos_;
#else
out vec3 aVertexPos_;
#endif

void main() {
    vec3 vertex_position_ws = (uMMatrix * vec4(aVertexPosition, 1.0)).xyz;
    aVertexPos_ = vertex_position_ws;

    gl_Position = shrd_data.uViewProjMatrix * uMMatrix * vec4(aVertexPosition, 1.0);
}