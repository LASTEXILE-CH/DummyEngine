#include "Viewer.h"

#include <sstream>

#include <Eng/GameStateManager.h>
#include <Eng/Renderer/Renderer.h>
#include <Eng/Scene/SceneManager.h>
#include <Eng/Utils/Cmdline.h>
#include <Ray/RendererFactory.h>
#include <Ren/Context.h>
#include <Ren/MVec.h>
#include <Sys/AssetFile.h>
#include <Sys/Json.h>
#include <Sys/Log.h>

#include "Gui/DebugInfoUI.h"
#include "Gui/FontStorage.h"
#include "States/GSCreate.h"

Viewer::Viewer(int w, int h, const char *local_dir) : GameBase(w, h, local_dir) {
    auto ctx = GetComponent<Ren::Context>(REN_CONTEXT_KEY);
    JsObject main_config;

    {
        // load config
#if defined(__ANDROID__)
        Sys::AssetFile config_file("assets/config.json", Sys::AssetFile::FileIn);
#else
        Sys::AssetFile config_file("assets_pc/config.json", Sys::AssetFile::FileIn);
#endif
        size_t config_file_size = config_file.size();
        
        std::unique_ptr<char[]> buf(new char[config_file_size]);
        config_file.Read(buf.get(), config_file_size);

        std::stringstream ss;
        ss.write(buf.get(), config_file_size);

        if (!main_config.Read(ss)) {
            throw std::runtime_error("Unable to load main config!");
        }
    }

    const auto &ui_settings = (const JsObject &)main_config.at("ui_settings");

    {   // load fonts
        auto font_storage = std::make_shared<FontStorage>();
        AddComponent(UI_FONTS_KEY, font_storage);

        const auto &fonts = (const JsObject &)ui_settings.at("fonts");
        for (const auto &el : fonts.elements) {
            const std::string &name = el.first;
            

#if defined(__ANDROID__)
            std::string file_name = std::string("assets/");
#else
            std::string file_name = std::string("assets_pc/");
#endif
            file_name += ((const JsString &)el.second).val;

            font_storage->LoadFont(name, file_name, ctx.get());
        }
    }

    {   // create commnadline
        auto cmdline = std::make_shared<Cmdline>();
        AddComponent(CMDLINE_KEY, cmdline);
    }

    {   // create UI for performance debugging
        auto font_storage = GetComponent<FontStorage>(UI_FONTS_KEY);
        auto ui_root = GetComponent<Gui::BaseElement>(UI_ROOT_KEY);
        auto debug_ui = std::make_shared<DebugInfoUI>(Ren::Vec2f{ -1.0f, -1.0f }, Ren::Vec2f{ 2.0f, 2.0f }, ui_root.get(), font_storage->FindFont("main_font"));
        AddComponent(UI_DEBUG_KEY, debug_ui);
    }

    {
        auto threads = GetComponent<Sys::ThreadPool>(THREAD_POOL_KEY);
        auto renderer = std::make_shared<Renderer>(*ctx, threads);
        AddComponent(RENDERER_KEY, renderer);

        Ray::settings_t s;
        s.w = w;
        s.h = h;

        auto ray_renderer = Ray::CreateRenderer(s, Ray::RendererSSE2 | Ray::RendererAVX | Ray::RendererAVX2 /*| Ray::RendererOCL*/);
        AddComponent(RAY_RENDERER_KEY, ray_renderer);

        auto scene_manager = std::make_shared<SceneManager>(*ctx, *ray_renderer, *threads);
        AddComponent(SCENE_MANAGER_KEY, scene_manager);
    }

#if defined(__ANDROID__)
    auto input_manager = GetComponent<InputManager>(INPUT_MANAGER_KEY);
    const Ren::Context *p_ctx = ctx.get();
    input_manager->SetConverter(EvP1Move, [p_ctx](InputManager::Event &evt) {
        evt.move.dx *= 300.0f / p_ctx->w();
        evt.move.dy *= 300.0f / p_ctx->w();
    });
    input_manager->SetConverter(EvP2Move, [p_ctx](InputManager::Event &evt) {
        evt.move.dx *= 300.0f / p_ctx->w();
        evt.move.dy *= 300.0f / p_ctx->w();
    });
#endif

    auto swap_interval = std::make_shared<TimeInterval>();
    AddComponent(SWAP_TIMER_KEY, swap_interval);

    auto state_manager = GetComponent<GameStateManager>(STATE_MANAGER_KEY);
    state_manager->Push(GSCreate(GS_DRAW_TEST, this));
}

void Viewer::Resize(int w, int h) {
    GameBase::Resize(w, h);
}

void Viewer::Frame() {
    auto state_manager = GetComponent<GameStateManager>(STATE_MANAGER_KEY);
    state_manager->Draw(0);
}

void Viewer::PrepareAssets(const char *platform) {
#if !defined(__ANDROID__)
    if (strcmp(platform, "all") == 0) {
        SceneManager::PrepareAssets("assets", "assets_pc", "pc", nullptr);
        SceneManager::PrepareAssets("assets", "assets_android", "android", nullptr);
    } else {
        std::string out_folder = "assets_";
        out_folder += platform;
        SceneManager::PrepareAssets("assets", out_folder.c_str(), platform, nullptr);
    }
#endif
}
