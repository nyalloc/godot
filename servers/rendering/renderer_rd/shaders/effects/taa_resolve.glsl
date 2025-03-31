#[compute]

#version 450

#VERSION_DEFINES

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_buffer;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D output_buffer;

void main()
{
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	vec4 color_input = imageLoad(color_buffer, pos);
	imageStore(output_buffer, pos, color_input);
}
