shader_type canvas_item;

// Colores de la paleta GameBoy (Normalizados de 0.0 a 1.0)
uniform vec4 color_1 : source_color = vec4(0.031, 0.094, 0.125, 1.0); // e0f8d0 (Claro)
uniform vec4 color_2 : source_color = vec4(0.204, 0.408, 0.337, 1.0); // 88c070 (Medio-Claro)
uniform vec4 color_3 : source_color = vec4(0.533, 0.753, 0.439, 1.0); // 346856 (Medio-Oscuro)
uniform vec4 color_4 : source_color = vec4(0.878, 0.973, 0.816, 1.0); // 081820 (Oscuro)

// Variables interactivas para el menú
uniform float hover_progress : hint_range(0.0, 1.0) = 0.0;   // Controla el brillo/barrido al pasar el mouse (0 a 1)
uniform bool is_pressed = false;                             // Invierte la paleta de color al hacer click

void fragment() {
    // MULTIPLICAMOS por COLOR para absorber los colores nativos de la fuente y del StyleBox Flat
    vec4 tex_color = texture(TEXTURE, UV) * COLOR;

    // CORTE SEGURO DE ALFA: Si el pixel es prácticamente invisible, detenemos el procesamiento
    // Esto evita bloques opacos donde el fondo del botón debería ser transparente
    if (tex_color.a < 0.05) {
        COLOR = vec4(0.0);
    }

    // Calculamos el brillo usando pesos de luminancia reales (gris mucho más natural)
    float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));

    // Si el botón está presionado, invertimos el mapa de grises para un efecto LCD táctil
    if (is_pressed) {
        gray = 1.0 - gray;
    }

    vec4 final_color;

    // Mapeamos el nivel de gris a uno de los 4 colores de la paleta
    if (gray > 0.75) {
        final_color = color_1;
    } else if (gray > 0.5) {
        final_color = color_2;
    } else if (gray > 0.25) {
        final_color = color_3;
    } else {
        final_color = color_4;
    }

    // --- EFECTO HOVER: Barrido de iluminación retro de fósforo ---
    if (hover_progress > 0.0) {
        // Ecuación de línea diagonal en base a UVs
        float line_pos = (UV.x + UV.y) * 0.5;
        // Sincronizamos el movimiento de la línea con el progreso del uniforme
        float dist = abs(line_pos - (hover_progress * 1.5 - 0.25));

        // Si el pixel está dentro del rango del haz de luz, subimos un escalón en la paleta
        if (dist < 0.08) {
            if (final_color == color_4) final_color = color_3;
            else if (final_color == color_3) final_color = color_2;
            else if (final_color == color_2) final_color = color_1;
        }
    }

    // Retornamos el color indexado respetando el canal alfa resultante
    COLOR = vec4(final_color.rgb, tex_color.a);
}