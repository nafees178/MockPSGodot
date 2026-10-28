shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.35;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.28;
uniform float aberration_amount : hint_range(0.0, 0.05) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Chromatic aberration (color channel offset away from screen center)
	vec4 color;
	if (aberration_amount > 0.0001) {
		vec2 dist = uv - vec2(0.5);
		vec2 offset = dist * aberration_amount;
		float r = texture(screen_texture, uv - offset).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv + offset).b;
		float a = texture(screen_texture, uv).a;
		color = vec4(r, g, b, a);
	} else {
		color = texture(screen_texture, uv);
	}
	
	// Smooth vignette for depth and cinematic focus
	vec2 uv_v = (uv - vec2(0.5)) * 2.0;
	float vignette = clamp(dot(uv_v, uv_v) * vignette_intensity, 0.0, 1.0);
	color.rgb = mix(color.rgb, color.rgb * (1.0 - vignette), vignette_opacity);
	
	// Dynamic screen flash / danger tint
	if (flash_color.a > 0.001) {
		color.rgb = mix(color.rgb, flash_color.rgb, flash_color.a);
	}
	
	COLOR = color;
}
