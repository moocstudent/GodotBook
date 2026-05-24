// GDExtension 入口:Godot 启动时通过 entry_symbol 调用这里。
#include "register_types.h"
#include "sine_bobber.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_godotstuff_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    // 在这里把你的所有 C++ 类注册到 Godot 的 ClassDB
    GDREGISTER_CLASS(SineBobber);
}

void uninitialize_godotstuff_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {

// 函数名必须与 .gdextension 里 entry_symbol 一致
GDExtensionBool GDE_EXPORT godotstuff_library_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization) {

    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
    init_obj.register_initializer(initialize_godotstuff_module);
    init_obj.register_terminator(uninitialize_godotstuff_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}

}
