shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always;

uniform float outline_width : hint_range(0.0, 0.1) = 0.002;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float edge_detection_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float max_outline_distance : hint_range(1.0, 100.0) = 50.0;
uniform bool adaptive_width = true;
uniform float sharp_edge_multiplier : hint_range(0.5, 3.0) = 1.5;

varying float edge_factor;

void vertex() {
    vec3 object_normal = NORMAL;
    vec3 object_position = VERTEX;
    
    // エッジの鋭さを計算（インライン化）
    float tangent_variation = abs(dot(object_normal, TANGENT));
    float binormal_variation = abs(dot(object_normal, BINORMAL));
    float edge_sharpness = max(tangent_variation, binormal_variation);
    
    // 鋭角部分でのアウトライン幅調整
    float width_multiplier = 1.0;
    if (edge_sharpness > edge_detection_threshold) {
        width_multiplier = sharp_edge_multiplier;
    }
    
    // カメラからの距離に基づく適応的幅調整
    if (adaptive_width) {
        vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
        float distance_to_camera = length(world_pos - camera_pos);
        float distance_factor = clamp(distance_to_camera / max_outline_distance, 0.5, 2.0);
        width_multiplier *= distance_factor;
    }
    
    // アウトライン用の強化された法線を計算（インライン化）
    vec3 edge_correction = vec3(0.0);
    if (edge_sharpness > edge_detection_threshold) {
        // タンジェントとバイノーマルを使用してエッジ方向を計算
        vec3 edge_direction = normalize(cross(TANGENT, BINORMAL));
        edge_correction = edge_direction * edge_sharpness * 0.5;
    }
    vec3 enhanced_normal = normalize(object_normal + edge_correction);
    
    // 頂点の押し出し
    VERTEX += enhanced_normal * outline_width * width_multiplier;
    
    edge_factor = edge_sharpness;
}

void fragment() {
    // エッジの鋭さに基づいて色を微調整（オプション）
    vec3 final_color = outline_color.rgb;
    
    // 鋭角部分を少し強調（オプション）
    if (edge_factor > edge_detection_threshold) {
        final_color *= 0.9; // 少し暗くして強調
    }
    
    ALBEDO = final_color;
    ALPHA = outline_color.a;
}