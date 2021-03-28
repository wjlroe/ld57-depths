#version 150 core

in vec4 v_Color;
in vec2 TexCoords;
out vec4 Target0;

uniform int sample_texture;
uniform sampler2D texture1;

uniform vec4 color;

void main() {
  if (sample_texture == 0) {
    // static colour
    Target0 = color;
  } else {
    vec4 texture_color = texture(texture1, TexCoords);
    float final_alpha = color.a * texture_color.r;
    Target0 = vec4(color.rgb, final_alpha);
  }
}
