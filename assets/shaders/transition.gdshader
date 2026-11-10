shader_type canvas_item;

uniform float progress : hint_range(0, 1) = 1.0;
uniform float pixel_size : hint_range(2, 100) = 64.0;
// El color 081820 convertido a decimal: R:0.031, G:0.094, B:0.125
uniform vec4 base_color : source_color = vec4(0.031, 0.094, 0.125, 1.0);

void fragment() {
    // Definimos el tamaño de los bloques de píxeles
    vec2 grid_uv = round(UV * pixel_size) / pixel_size;

    // Generamos un patrón de desvanecimiento
    // Usamos una pequeña variación matemática para que los píxeles no desaparezcan todos a la vez
    float mask_value = fract(grid_uv.x * 8.0 + grid_uv.y * 4.0);
    // Si progress es 1.0, el step debería dar 0.0 (invisible)
	float mask = step(progress, mask_value);

    // Aplicamos tu verde oscuro con la máscara de transparencia
    COLOR = vec4(base_color.rgb, mask);
}