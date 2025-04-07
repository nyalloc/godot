#[compute]

#version 450

#VERSION_DEFINES

#define FLT_MAX (3.402823466e+38)
#define FLT_MIN (1.175494351e-38)

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D scene_color_buffer;
layout(set = 0, binding = 1) uniform sampler2D depth_buffer;
layout(rg16f, set = 0, binding = 2) uniform restrict readonly image2D velocity_buffer;
layout(rg16f, set = 0, binding = 3) uniform restrict readonly image2D prev_velocity_buffer;
layout(set = 0, binding = 4) uniform sampler2D prev_scene_color_buffer;
layout(rgba16f, set = 0, binding = 5) uniform restrict writeonly image2D output_buffer;

layout(push_constant, std430) uniform Params {
	vec2 resolution;
}
params;

const ivec2 neighborhood_3x3[9] = {
	ivec2(-1, -1),
	ivec2(0, -1),
	ivec2(1, -1),
	ivec2(-1, 0),
	ivec2(0, 0),
	ivec2(1, 0),
	ivec2(-1, 1),
	ivec2(0, 1),
	ivec2(1, 1),
};

void get_min_max_color(ivec2 pixel, uint i, inout vec3 min_color, inout vec3 max_color) {
	const ivec2 pos = pixel + neighborhood_3x3[i];
	const vec3 color = imageLoad(scene_color_buffer, pos).rgb;
	min_color = min(min_color, color);
	max_color = max(max_color, color);
}

vec3 neighborhood_clamp_rgb(vec3 prev_color, ivec2 pixel)
{
	vec3 min_color = FLT_MAX.xxx;
	vec3 max_color = FLT_MIN.xxx;
	get_min_max_color(pixel, 0, min_color, max_color);
	get_min_max_color(pixel, 1, min_color, max_color);
	get_min_max_color(pixel, 2, min_color, max_color);
	get_min_max_color(pixel, 3, min_color, max_color);
	get_min_max_color(pixel, 4, min_color, max_color);
	get_min_max_color(pixel, 5, min_color, max_color);
	get_min_max_color(pixel, 6, min_color, max_color);
	get_min_max_color(pixel, 7, min_color, max_color);
	get_min_max_color(pixel, 8, min_color, max_color);
	return clamp(prev_color, min_color, max_color);
}

vec3 sample_history(ivec2 pixel, vec2 prev_uv)
{
	const vec3 prev_color = textureLod(prev_scene_color_buffer, prev_uv, 0.0).rgb;
#ifdef TAA_HISTORY_RECTIFICATION_NEIGHBORHOOD_CLAMP_RGB
	return neighborhood_clamp_rgb(prev_color, pixel);
#else
	return prev_color;
#endif
}

void get_nearest_depth_and_pos(ivec2 pixel, uint i, inout float nearest_depth, inout ivec2 nearest_pos) {
	const ivec2 pos = pixel + neighborhood_3x3[i];
	const float depth = texelFetch(depth_buffer, pos, 0).r;
	if (depth < nearest_depth) {
		nearest_depth = depth;
		nearest_pos = pixel;
	}
}

ivec2 find_nearest_neighbour(ivec2 pixel) {
	float nearest_depth = 1.0;
	ivec2 nearest_pos = pixel;
	get_nearest_depth_and_pos(pixel, 0, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 1, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 2, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 3, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 4, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 5, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 6, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 7, nearest_depth, nearest_pos);
	get_nearest_depth_and_pos(pixel, 8, nearest_depth, nearest_pos);
	return nearest_pos;
}

vec2 reprojection(ivec2 pixel, vec2 uv)
{
#ifdef TAA_REPROJECTION_NEAREST_VELOCITY
	pixel = find_nearest_neighbour(pixel);
#endif
	const vec2 velocity = imageLoad(velocity_buffer, pixel).xy;
	return uv + velocity;
}

void main()
{
	const ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	const vec3 current_color = imageLoad(scene_color_buffer, pixel).rgb;
#ifdef TAA_RESOLVE
	const vec2 uv = (gl_GlobalInvocationID.xy + 0.5f) / params.resolution;
	const vec2 prev_uv = reprojection(pixel, uv);
	const vec3 prev_color = sample_history(pixel, prev_uv);
	const float source_weight = 0.9;
	const vec3 final_color = mix(current_color, prev_color, source_weight);
	imageStore(output_buffer, pixel, vec4(final_color, 1.0f));
#else
	imageStore(output_buffer, pixel, vec4(current_color, 1.0f));
#endif
}
