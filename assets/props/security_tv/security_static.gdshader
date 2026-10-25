shader_type canvas_item;
render_mode unshaded;

uniform vec4 background_color : source_color = vec4(0.015, 0.05, 0.045, 1.0);

uniform float noise_intensity : hint_range(0.0, 1.0) = 0.65;
uniform float animation_speed : hint_range(1.0, 60.0) = 18.0;

uniform float block_scale_x : hint_range(20.0, 300.0) = 110.0;
uniform float block_scale_y : hint_range(20.0, 300.0) = 60.0;

uniform float fine_noise_scale_x : hint_range(50.0, 600.0) = 260.0;
uniform float fine_noise_scale_y : hint_range(50.0, 600.0) = 180.0;

uniform float glitch_strength : hint_range(0.0, 1.0) = 0.28;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.24;
uniform float flicker_strength : hint_range(0.0, 0.5) = 0.05;

float random_noise(vec2 position) {
	return fract(
		sin(dot(position, vec2(12.9898, 78.233)))
		* 43758.5453
	);
}

void fragment() {
	// Tempo em "quadros" para a interferência
	float frame = floor(TIME * animation_speed);

	// Ruído em blocos maiores
	vec2 block_grid = floor(UV * vec2(block_scale_x, block_scale_y));
	float block_noise = random_noise(
		block_grid + vec2(frame * 17.0, frame * 41.0)
	);

	// Ruído fino para dar textura de TV
	vec2 fine_grid = floor(UV * vec2(fine_noise_scale_x, fine_noise_scale_y));
	float fine_noise = random_noise(
		fine_grid + vec2(frame * 67.0, frame * 31.0)
	);

	// Mistura dos dois ruídos
	float noise = mix(block_noise, fine_noise, 0.45);

	// Linhas horizontais de interferência
	float row = floor(UV.y * 95.0);
	float interference = random_noise(vec2(row, frame * 7.0));
	float glitch_line = smoothstep(0.92, 1.0, interference) * glitch_strength;

	// Bandas horizontais maiores se movendo
	float band = sin((UV.y * 18.0) - TIME * 6.0) * 0.5 + 0.5;
	float moving_band = smoothstep(0.72, 1.0, band) * 0.08;

	// Scanlines estilo CRT
	float scanlines = mix(
		1.0,
		1.0 - scanline_strength,
		step(1.0, mod(floor(UV.y * 180.0), 2.0))
	);

	// Flicker geral da tela
	float flicker = 1.0 - flicker_strength + random_noise(vec2(frame, 99.0)) * flicker_strength;

	// Paleta verde-escura de monitor de vigilância
	vec3 static_color = vec3(0.16, 0.40, 0.30) * noise * noise_intensity;

	vec3 final_color = background_color.rgb;
	final_color += static_color;
	final_color += vec3(0.04, 0.20, 0.13) * glitch_line;
	final_color += vec3(0.02, 0.08, 0.06) * moving_band;

	final_color *= scanlines;
	final_color *= flicker;

	COLOR = vec4(
		clamp(final_color, vec3(0.0), vec3(1.0)),
		1.0
	);
}