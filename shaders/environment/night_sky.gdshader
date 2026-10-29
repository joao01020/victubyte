shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.008, 0.024, 0.090, 1.0);
uniform vec4 middle_color : source_color = vec4(0.027, 0.086, 0.220, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.141, 0.125, 0.322, 1.0);

void fragment() {
    float y = UV.y;

    vec3 sky = mix(
        top_color.rgb,
        middle_color.rgb,
        smoothstep(0.0, 0.65, y)
    );

    sky = mix(
        sky,
        horizon_color.rgb,
        smoothstep(0.55, 0.85, y)
    );

    COLOR = vec4(sky, 1.0);
}