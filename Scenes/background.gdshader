shader_type canvas_item;

uniform float gradient_strength : hint_range(0.0, 0.5) = 0.2;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec4 original = texture(TEXTURE, UV);

    // Convertir a escala de grises
    float luminance = dot(original.rgb, vec3(0.299, 0.587, 0.114));
    vec3 grayscale = vec3(luminance);

    // Gradiente radial desde el centro
    vec2 center = UV - 0.5;
    float distance_from_center = length(center);
    float radial_gradient = distance_from_center * 2.0;

    // Efecto vignette (oscurecimiento en bordes)
    float vignette = 1.0 - (radial_gradient * radial_gradient * vignette_strength);

    // Gradiente direccional sutil en blanco y negro
    float directional_gradient = (UV.x + UV.y) * 0.5;
    directional_gradient = directional_gradient * 2.0 - 1.0; // -1 a 1

    // Combinar efectos - usar tonos de gris en lugar de color
    float gradient_effect = gradient_strength * directional_gradient;
    vec3 final_color = grayscale + gradient_effect;
    final_color *= vignette; // Aplicar vignette

    final_color = clamp(final_color, 0.0, 1.0);

    COLOR = vec4(final_color, original.a);
}