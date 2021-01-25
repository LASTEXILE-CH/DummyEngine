#pragma once

#include "../Graph/GraphBuilder.h"
#include "../Renderer_DrawList.h"

#if defined(USE_GL_RENDER)
#include <Ren/VaoGL.h>
#endif

class PrimDraw;

class RpDebugProbes : public RenderPassBase {
    PrimDraw &prim_draw_;
    bool initialized = false;
    float debug_roughness_ = 0.0f;

    // temp data (valid only between Setup and Execute calls)
    const ProbeStorage *probe_storage_ = nullptr;
    DynArrayConstRef<ProbeItem> probes_;
    const ViewState *view_state_ = nullptr;
    int orphan_index_ = -1;

    RpResource shared_data_buf_;

    RpResource output_tex_;

    void LazyInit(Ren::Context &ctx, ShaderLoader &sh, RpAllocTex &output_tex);
    void DrawProbes(RpBuilder &builder);

    // lazily initialized data
#if defined(USE_GL_RENDER)
    Ren::ProgramRef probe_prog_;
    Ren::Framebuffer draw_fb_;
#endif
  public:
    RpDebugProbes(PrimDraw &prim_draw) : prim_draw_(prim_draw) {}

    void Setup(RpBuilder &builder, const DrawList &list, const ViewState *view_state,
               int orphan_index, const char shared_data_buf_name[],
               const char output_tex_name[]);
    void Execute(RpBuilder &builder) override;

    // TODO: remove this
    int alpha_blend_start_index_ = -1;

    const char *name() const override { return "DEBUG PROBES"; }
};