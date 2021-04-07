#version 150 core

in vec4 v_Color;
in vec2 TexCoords;
out vec4 Target0;

uniform vec4 color;

void main() {
  float radius = 1.0;
  float distance = sqrt(dot(TexCoords,TexCoords));
  if (distance >= radius) {
    discard;
  }
  Target0 = color;
}
