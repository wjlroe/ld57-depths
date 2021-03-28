pub usingnamespace @cImport({
    @cInclude("GL/glcorearb.h");
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("stb/stb_truetype.h");
    @cInclude("stb/stb_image.h");
});
