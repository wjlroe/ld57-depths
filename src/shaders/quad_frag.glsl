#version 150 core

in vec4 v_Color;
in vec2 TexCoords;
out vec4 Target0;

uniform int sample_texture;
uniform sampler2D texture1;
uniform float gap_height; // dashed vertical lines

uniform vec4 color;

void main() {
  float AlphaValue = 1.0;
  // Dashed vertical lines
  if (gap_height > 0.0) {
    vec2 this_point = gl_FragCoord.xy;
    if (mod(this_point.y, gap_height) <= (gap_height / 2.0)) {
      AlphaValue = 1.0;
    } else {
      AlphaValue = 0.0;
    }
  }

  if (sample_texture == 0) {
    // static colour
    float final_alpha = color.a * AlphaValue;
    Target0 = vec4(color.rgb, final_alpha);
  } else {
    vec4 texture_color = texture(texture1, TexCoords);
    float final_alpha = color.a * texture_color.r * AlphaValue;
    Target0 = vec4(color.rgb, final_alpha);
  }
}
