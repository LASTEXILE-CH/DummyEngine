#pragma once

#include "../Graph/GraphBuilder.h"

class PrimDraw;

class RpDownColor : public RenderPassBase {
    PrimDraw &prim_draw_;
    bool initialized = false;

    // lazily initialized data
    Ren::ProgramRef blit_down_prog_;

    // temp data (valid only between Setup and Execute calls)
    Ren::TexHandle color_tex_, output_tex_;
    const ViewState *view_state_ = nullptr;
    int orphan_index_ = -1;

    void LazyInit(Ren::Context &ctx, ShaderLoader &sh);

#if defined(USE_GL_RENDER)
    Ren::Framebuffer draw_fb_;
#endif
  public:
    RpDownColor(PrimDraw &prim_draw) : prim_draw_(prim_draw) {}

    void Setup(RpBuilder &builder, const ViewState *view_state, int orphan_index,
               Ren::TexHandle color_tex, Ren::TexHandle output_tex);
    void Execute(RpBuilder &builder) override;

    const char *name() const override { return "DOWNSAMPLE COLOR"; }
};