#pragma once

#include "../Input/InputManager.h"
#include <Ren/MMat.h>

class FreeCamController {
    float move_region_frac_;
    int width_, height_;
    int view_pointer_ = 0, move_pointer_ = 0;

    float fwd_press_speed_ = 0, side_press_speed_ = 0, fwd_touch_speed_ = 0,
          side_touch_speed_ = 0;
  public:
    FreeCamController(int width, int height, float move_region_frac);

    void Resize(int w, int h);

    void Update(uint64_t dt_us);

    bool HandleInput(const InputManager::Event &evt);

    float max_fwd_speed = 1.0f;
    float fwd_speed = 0.0f, side_speed = 0.0f;
    Ren::Vec3f view_origin, view_dir = Ren::Vec3f{0.0f, 0.0f, -1.0f};
    float view_fov = 45.0f, max_exposure = 1000.0f;
    bool invalidate_view = false;
};