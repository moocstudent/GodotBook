#ifndef SINE_BOBBER_H
#define SINE_BOBBER_H

#include <godot_cpp/classes/node2d.hpp>

namespace godot {

class SineBobber : public Node2D {
    GDCLASS(SineBobber, Node2D)

private:
    double amplitude = 32.0;
    double frequency = 1.0;
    double phase = 0.0;

    double elapsed = 0.0;
    Vector2 origin;

protected:
    // _bind_methods 是 GDExtension 注册属性/方法/信号的入口
    static void _bind_methods();

public:
    SineBobber();
    ~SineBobber();

    // 这两个是 Godot 自动调用的生命周期(对应 GDScript 的 _ready / _process)
    void _ready() override;
    void _process(double delta) override;

    // 暴露给 Godot 的属性 setter/getter
    void   set_amplitude(double v);
    double get_amplitude() const;
    void   set_frequency(double v);
    double get_frequency() const;
    void   set_phase(double v);
    double get_phase() const;
};

}

#endif
