shader_type canvas_item;

uniform float color_cycle_speed : hint_range(0.1, 3.0) = 1.0;
uniform float color_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float pixel_size : hint_range(2.0, 20.0) = 8.0;

// Colores Game Boy
const vec3 GB_COLOR_1 = vec3(0.031, 0.094, 0.125);    // #081820
const vec3 GB_COLOR_2 = vec3(0.204, 0.408, 0.337);    // #346856
const vec3 GB_COLOR_3 = vec3(0.533, 0.753, 0.439);    // #88c070
const vec3 GB_COLOR_4 = vec3(0.878, 0.973, 0.816);    // #e0f8d0

void fragment() {
    vec4 original = texture(TEXTURE, UV);

    if (original.a > 0.1) {
        // Crear coordenadas pixeladas
        vec2 pixelated_uv = floor(UV * pixel_size) / pixel_size;
        
        // Crear efecto de ciclo de colores basado en posición pixelada y tiempo
        float cycle = (pixelated_uv.x + pixelated_uv.y) * 0.5 + TIME * color_cycle_speed;
        cycle = fract(cycle); // Mantener en rango 0-1
        
        // Seleccionar color de la paleta Game Boy basado en el ciclo
        vec3 gb_color;
        if (cycle < 0.25) {
            gb_color = GB_COLOR_1;
        } else if (cycle < 0.5) {
            gb_color = GB_COLOR_2;
        } else if (cycle < 0.75) {
            gb_color = GB_COLOR_3;
        } else {
            gb_color = GB_COLOR_4;
        }

        // Mezclar con color original
        vec3 final_color = mix(original.rgb, gb_color, color_intensity);

        COLOR = vec4(final_color, original.a);
    } else {
        COLOR = vec4(0.0);
    }
}