#[compute]

#version 450

#VERSION_DEFINES

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_buffer;
layout(set = 0, binding = 1) uniform sampler2D depth_buffer;
layout(rg16f, set = 0, binding = 2) uniform restrict readonly image2D velocity_buffer;
layout(rg16f, set = 0, binding = 3) uniform restrict readonly image2D last_velocity_buffer;
layout(set = 0, binding = 4) uniform sampler2D history_buffer;
layout(rgba16f, set = 0, binding = 5) uniform restrict writeonly image2D output_buffer;

layout(push_constant, std430) uniform Params {
	vec2 resolution;
}
params;

void main()
{
	const ivec2 pos_screen = ivec2(gl_GlobalInvocationID.xy);
	const vec2 uv = (gl_GlobalInvocationID.xy + 0.5f) / params.resolution;

	vec2 velocity = imageLoad(velocity_buffer, pos_screen).xy;
	vec2 prev_uv = uv + velocity;

	vec4 current_color = imageLoad(color_buffer, pos_screen);
	vec4 prev_color = textureLod(history_buffer, prev_uv, 0.0);

	vec4 minColor = 9999.0.xxxx;
	vec4 maxColor = -9999.0.xxxx;
	for(int x = -1; x <= 1; ++x)
	{
		for(int y = -1; y <= 1; ++y)
		{
			vec4 color = imageLoad(color_buffer, pos_screen + ivec2(x, y));
			minColor = min(minColor, color);
			maxColor = max(maxColor, color);
		}
	}
	vec4 prev_color_clamped = clamp(prev_color, minColor, maxColor);

	vec4 final_color = (current_color * 0.1) + (prev_color_clamped * 0.9);
	imageStore(output_buffer, pos_screen, final_color);
}
