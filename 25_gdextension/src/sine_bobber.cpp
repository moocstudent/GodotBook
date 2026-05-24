#include "sine_bobber.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void SineBobber::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_amplitude", "v"), &SineBobber::set_amplitude);
    ClassDB::bind_method(D_METHOD("get_amplitude"),     &SineBobber::get_amplitude);
    ClassDB::bind_method(D_METHOD("set_frequency", "v"), &SineBobber::set_frequency);
    ClassDB::bind_method(D_METHOD("get_frequency"),     &SineBobber::get_frequency);
    ClassDB::bind_method(D_METHOD("set_phase", "v"),    &SineBobber::set_phase);
    ClassDB::bind_method(D_METHOD("get_phase"),         &SineBobber::get_phase);

    // PropertyInfo 会让属性在 Inspector 里出现
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "amplitude"), "set_amplitude", "get_amplitude");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "frequency"), "set_frequency", "get_frequency");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "phase"),     "set_phase",     "get_phase");
}

SineBobber::SineBobber() {}
SineBobber::~SineBobber() {}

void SineBobber::_ready() {
    origin = get_position();
}

void SineBobber::_process(double delta) {
    // 编辑器里也跑会让 Inspector 拖动时鬼畜,这里跳过
    if (Engine::get_singleton()->is_editor_hint()) {
        return;
    }
    elapsed += delta;
    double offset_y = std::sin(elapsed * frequency * 2.0 * 3.141592653589793 + phase) * amplitude;
    set_position(Vector2(origin.x, origin.y + (real_t)offset_y));
}

// ── setter / getter ───────────────────────────────────────────

void   SineBobber::set_amplitude(double v) { amplitude = v; }
double SineBobber::get_amplitude() const   { return amplitude; }
void   SineBobber::set_frequency(double v) { frequency = v; }
double SineBobber::get_frequency() const   { return frequency; }
void   SineBobber::set_phase(double v)     { phase = v; }
double SineBobber::get_phase() const       { return phase; }
