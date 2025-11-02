shader_type canvas_item;

// Velocidad de movimiento
uniform float speed : hint_range(0.0, 5.0) = 1.0;
// Escala de las nubes
uniform float cloud_scale : hint_range(0.1, 10.0) = 3.0;
// Suavidad de las nubes
uniform float softness : hint_range(0.1, 5.0) = 2.0;
// Resolución PS1 (baja resolución)
uniform float ps1_resolution : hint_range(32.0, 480.0) = 240.0;
// Intensidad del vertex snapping
uniform float vertex_snap_intensity : hint_range(0.0, 1.0) = 0.5;

// NUEVA PALETA DE COLORES
const vec4 COLOR_DARKEST = vec4(0.063, 0.145, 0.2, 1.0);     // #102533
const vec4 COLOR_DARK = vec4(0.259, 0.404, 0.557, 1.0);      // #42678e
const vec4 COLOR_MEDIUM = vec4(0.435, 0.62, 0.875, 1.0);     // #6f9edf
const vec4 COLOR_LIGHT = vec4(0.808, 0.808, 0.808, 1.0);     // #cecece

// Función de ruido simple
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + 
           (c - a) * u.y * (1.0 - u.x) + 
           (d - b) * u.x * u.y;
}

// Función para aplicar baja resolución (como PS1)
vec2 apply_ps1_resolution(vec2 uv, float resolution) {
    return floor(uv * resolution) / resolution;
}

// Función para vertex snapping (efecto wobble característico de PS1)
vec2 vertex_snap(vec2 uv, float intensity) {
    // Crear un snapping basado en el tiempo para simular el wobble
    float snap_x = sin(TIME * 2.0 + uv.y * 10.0) * 0.002 * intensity;
    float snap_y = cos(TIME * 1.5 + uv.x * 8.0) * 0.002 * intensity;
    return vec2(uv.x + snap_x, uv.y + snap_y);
}

// Función para mapear el valor de las nubes a la paleta Gameboy con mezcla suave
vec4 apply_gameboy_palette_smooth(float intensity) {
    // Mezclar entre colores de forma gradual
    if (intensity < 0.33) {
        return mix(COLOR_DARKEST, COLOR_DARK, intensity * 3.0);
    } else if (intensity < 0.66) {
        return mix(COLOR_DARK, COLOR_MEDIUM, (intensity - 0.33) * 3.0);
    } else {
        return mix(COLOR_MEDIUM, COLOR_LIGHT, (intensity - 0.66) * 3.0);
    }
}

void fragment() {
    // Aplicar baja resolución PS1 (primero el vertex snapping)
    vec2 ps1_uv = vertex_snap(UV, vertex_snap_intensity);
    ps1_uv = apply_ps1_resolution(ps1_uv, ps1_resolution);
    
    vec2 uv = ps1_uv * cloud_scale;
    
    // Movimiento con el tiempo
    uv.x += TIME * speed * 0.1;
    uv.y += TIME * speed * 0.05;
    
    // Generar nubes con múltiples capas de ruido
    float clouds = 0.0;
    clouds += noise(uv) * 0.5;
    clouds += noise(uv * 2.0 + TIME * 0.2) * 0.25;
    clouds += noise(uv * 4.0 - TIME * 0.1) * 0.125;
    
    // Ajustar suavidad y contraste
    clouds = smoothstep(0.3, 0.7, clouds);
    clouds = pow(clouds, softness);
    
    // Aplicar paleta Gameboy
    COLOR = apply_gameboy_palette_smooth(clouds);
}