shader_type canvas_item;

// Colores de la paleta GameBoy (Normalizados de 0.0 a 1.0)
uniform vec4 color_1 : source_color = vec4(0.878, 0.973, 0.816, 1.0); // e0f8d0 (Claro)
uniform vec4 color_2 : source_color = vec4(0.533, 0.753, 0.439, 1.0); // 88c070 (Medio-Claro)
uniform vec4 color_3 : source_color = vec4(0.204, 0.408, 0.337, 1.0); // 346856 (Medio-Oscuro)
uniform vec4 color_4 : source_color = vec4(0.031, 0.094, 0.125, 1.0); // 081820 (Oscuro)

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // Si el pixel es transparente, no hacemos nada
    if (tex_color.a < 0.1) {
        discard;
    }

    // Calculamos el brillo promedio del pixel original (Gris)
    float gray = (tex_color.r + tex_color.g + tex_color.b) / 3.0;

    vec4 final_color;

    // Mapeamos el nivel de gris a uno de los 4 colores
    if (gray > 0.75) {
        final_color = color_1;
    } else if (gray > 0.5) {
        final_color = color_2;
    } else if (gray > 0.25) {
        final_color = color_3;
    } else {
        final_color = color_4;
    }

    COLOR = vec4(final_color.rgb, tex_color.a);
}