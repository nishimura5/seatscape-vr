shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform sampler2D albedo_texture : source_color;

uniform vec3 light_direction = vec3(0.0, -1.0, -1.0);
uniform float shade_threshold = 0.3;
uniform float dark_shade = 0.8;

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 l = normalize(-light_direction);

    float intensity = dot(n, l);
    float shade = intensity > shade_threshold ? 1.0 : dark_shade;

    vec4 tex_color = texture(albedo_texture, UV);
    ALBEDO = tex_color.rgb * shade;
    ALPHA = tex_color.a;
}