#pragma once

#include "../Graph/GraphBuilder.h"

class RpUpdateBuffers : public Graph::RenderPassBase {
    int orphan_index_ = 0;

    // temp data (valid only between Setup and Execute calls)
    void **fences_;
    DynArrayConstRef<SkinTransform> skin_transforms_;
    DynArrayConstRef<ShapeKeyData> shape_keys_data_;
    DynArrayConstRef<InstanceData> instances_;
    DynArrayConstRef<CellData> cells_;
    DynArrayConstRef<LightSourceItem> light_sources_;
    DynArrayConstRef<DecalItem> decals_;
    DynArrayConstRef<ItemData> items_;
    DynArrayConstRef<ShadowMapRegion> shadow_regions_;
    DynArrayConstRef<ProbeItem> probes_;
    DynArrayConstRef<EllipsItem> ellipsoids_;
    uint32_t render_flags_ = 0;

    const Environment *env_ = nullptr;

    const Ren::Camera *draw_cam_ = nullptr;
    const ViewState *view_state_ = nullptr;

  public:
    void Setup(Graph::RpBuilder &builder, const DrawList &list,
               const ViewState *view_state, int orphan_index, void **fences,
               Graph::ResourceHandle in_skin_transforms_buf,
               Graph::ResourceHandle in_shape_keys_buf,
               Graph::ResourceHandle in_instances_buf, Graph::ResourceHandle in_cells_buf,
               Graph::ResourceHandle in_lights_buf, Graph::ResourceHandle in_decals_buf,
               Graph::ResourceHandle in_items_buf,
               Graph::ResourceHandle in_shared_data_buf);
    void Execute(Graph::RpBuilder &builder) override;

    Graph::ResourceHandle out_skin_transforms_buf() const { return output_[0]; }
    Graph::ResourceHandle out_shape_keys_buf() const { return output_[1]; }
    Graph::ResourceHandle out_instances_buf() const { return output_[2]; }
    Graph::ResourceHandle out_cells_buf() const { return output_[3]; }
    Graph::ResourceHandle out_lights_buf() const { return output_[4]; }
    Graph::ResourceHandle out_items_buf() const { return output_[5]; }
    Graph::ResourceHandle out_shared_data_buf() const { return output_[7]; }

    const char *name() const override { return "UPDATE BUFFERS"; }
};