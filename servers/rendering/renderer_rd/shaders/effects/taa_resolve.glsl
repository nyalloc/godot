#[compute]

#version 450

#VERSION_DEFINES

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

vec3 neighborhood_clamp_rgb(vec3 prev_color, ivec2 pos_screen)
{
	vec3 minColor = 9999.0.xxx;
	vec3 maxColor = -9999.0.xxx;
	for(int x = -1; x <= 1; ++x)
	{
		for(int y = -1; y <= 1; ++y)
		{
			vec3 color = imageLoad(scene_color_buffer, pos_screen + ivec2(x, y)).rgb;
			minColor = min(minColor, color);
			maxColor = max(maxColor, color);
		}
	}
	return clamp(prev_color, minColor, maxColor);
}

vec3 history_rectification(vec3 prev_color, ivec2 pos_screen)
{
#ifdef TAA_HISTORY_RECTIFICATION_NEIGHBORHOOD_CLAMP_RGB
	return neighborhood_clamp_rgb(prev_color, pos_screen);
#else
	return prev_color;
#endif
}

void main()
{
	const ivec2 pos_screen = ivec2(gl_GlobalInvocationID.xy);
	vec3 current_color = imageLoad(scene_color_buffer, pos_screen).rgb;
#ifdef TAA_RESOLVE
	imageStore(output_buffer, pos_screen, vec4(current_color, 1.0f));
#else
	const vec2 uv = (gl_GlobalInvocationID.xy + 0.5f) / params.resolution;
	vec2 velocity = imageLoad(velocity_buffer, pos_screen).xy;
	vec2 prev_uv = uv + velocity;
	vec3 prev_color = textureLod(prev_scene_color_buffer, prev_uv, 0.0).rgb;
	vec3 prev_color_rectified = history_rectification(prev_color, pos_screen);
	const float currentWeight = 0.1;
	const float previousWeight = 0.9;
	vec3 final_color = (current_color * currentWeight) + (prev_color_rectified * previousWeight);
	imageStore(output_buffer, pos_screen, vec4(final_color, 1.0f));
#endif
}
