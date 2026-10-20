// [Lab Arcade] Fog of war drawn on the ground. The original draws it over the whole
// screen and works out where each pixel is from the depth buffer, which doesn't work
// in the OpenGL (Compatibility) renderer the arcade uses on phones. This version is a
// flat sheet just above the terrain that darkens what the units haven't seen.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(vec3(0.0), 1.0);
uniform sampler2D world_visibility_texture : hint_default_white, filter_linear, repeat_disable;
uniform int texture_units_per_world_unit = 2;

varying vec3 world_position;

void vertex()
{
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment()
{
  ALBEDO = color.rgb;
  vec2 size = vec2(textureSize(world_visibility_texture, 0)) / float(texture_units_per_world_unit);
  vec2 uv = world_position.xz / size;
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
  {
    ALPHA = 1.0;
  }
  else
  {
    ALPHA = 1.0 - textureLod(world_visibility_texture, uv, 0.0).r;
  }
}
