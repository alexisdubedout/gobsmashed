shader_type canvas_item;

uniform float strength  : hint_range(0.0, 1.0) = 0.55;
uniform float softness  : hint_range(0.0, 1.0) = 0.40;
uniform vec4  tint      : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2  uv   = UV - 0.5;
	float dist = length(uv) * 1.6;
	float v    = smoothstep(1.0 - softness, 1.0, dist) * strength;
	COLOR = vec4(tint.rgb, v);
}
