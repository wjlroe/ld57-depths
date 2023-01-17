#version 150 core

in vec2 a_Pos;
in vec2 a_Tex;

out vec2 TexCoords;

uniform float u_Z;
uniform mat4 pos_transform;
uniform mat4 tex_transform;
uniform mat4 ortho_transform;

void main() {
  TexCoords = (tex_transform * vec4(a_Tex, 0.0, 1.0)).xy;
  vec4 position = vec4(a_Pos, u_Z, 1.0);
  gl_Position = ortho_transform * pos_transform * position;
}
