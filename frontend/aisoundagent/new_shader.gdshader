shader_type canvas_item;

uniform float volume : hint_range(-60, 0) = -60; // 默认音量（dB）

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float fill_level = clamp(1.0 + (volume / 60.0), 0.0, 1.0); // 转换为0-1范围
    
    // 只显示音量条范围内的部分
    if (UV.x > fill_level) {
        color.a = 0.3; // 超出当前音量的部分半透明
    }
    
    COLOR = color;
}
