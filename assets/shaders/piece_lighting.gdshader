shader_type canvas_item;

uniform float shadow_softness : hint_range(0.0, 0.1) = 0.02;
uniform float shadow_offset_x : hint_range(-0.1, 0.1) = 0.01;
uniform float shadow_offset_y : hint_range(-0.1, 0.1) = 0.01;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.3);

void fragment() {
    // Primero dibujar la sombra
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 tex_color_shadow = texture(TEXTURE, UV - vec2(shadow_offset_x, shadow_offset_y));

    // Suavizar bordes de la sombra
    float shadow_alpha = 0.0;
    for(float x = -1.0; x <= 1.0; x += 1.0) {
        for(float y = -1.0; y <= 1.0; y += 1.0) {
            vec2 offset = vec2(x, y) * shadow_softness;
            shadow_alpha += texture(TEXTURE, UV - vec2(shadow_offset_x, shadow_offset_y) + offset).a;
        }
    }
    shadow_alpha /= 9.0;

    // Dibujar la pieza principal
    if (tex_color.a > 0.1) {
        // Iluminación simple
        vec2 center = UV - 0.5;
        float light = 1.0 - length(center) * 0.3;

        vec3 final_color = tex_color.rgb * light;

        // Combinar con sombra
        vec4 shadow_result = shadow_color * shadow_alpha;
        final_color = mix(shadow_result.rgb, final_color, tex_color.a);
        float final_alpha = max(shadow_alpha, tex_color.a);

        COLOR = vec4(final_color, final_alpha);
    } else if (shadow_alpha > 0.0) {
        // Solo dibujar sombra
        COLOR = shadow_color * shadow_alpha;
    } else {
        COLOR = vec4(0.0);
    }
}