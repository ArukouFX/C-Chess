shader_type canvas_item;

uniform float light_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec2 light_dir = vec2(0.7, 0.7);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (tex_color.a > 0.1) {
        // Calcular iluminación basada en la posición UV
        float light = dot(normalize(light_dir), normalize(UV - 0.5));
        light = (light + 1.0) * 0.5; // Convertir a rango 0-1

        // Aplicar iluminación
        vec3 lit_color = mix(tex_color.rgb, vec3(1.0), light * light_strength);
        COLOR = vec4(lit_color, tex_color.a);
    } else {
        COLOR = vec4(0.0);
    }
}