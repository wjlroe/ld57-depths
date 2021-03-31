const std = @import("std");
const opengl_renderer = @import("opengl_renderer.zig");
usingnamespace @import("opengl.zig");
usingnamespace @import("c.zig");
const console = @import("console.zig");
const command = @import("command.zig");
const Game = @import("game.zig").Game;

pub var game: *Game = undefined;

const cmd_or_control = if (std.builtin.os.tag == .macos) GLFW_MOD_SUPER else GLFW_MOD_CONTROL;

fn get_opengl_funcs(allocator: *std.mem.Allocator, open_gl: *OpenGL, comptime T: type) !void {
    comptime const info = @typeInfo(T);
    inline for (info.Struct.fields) |field| {
        if (@typeInfo(field.field_type) == .Fn) {
            const fun_name = try std.cstr.addNullByte(allocator, field.name);
            defer allocator.free(fun_name);
            @field(open_gl, field.name) = @ptrCast(field.field_type, glfwGetProcAddress(@ptrCast([*c]const u8, fun_name.ptr)));
            if (@ptrToInt(@field(open_gl, field.name)) == 0) {
                console.debug("Could not getProcAddress for {}\n", .{field.name});
                std.os.exit(1);
            }
        }
    }
}

fn key_to_cmd(key: c_int, action: c_int, mods: c_int) ?command.Command {
    if ((key == GLFW_KEY_Q) and (action == GLFW_PRESS) and ((mods & cmd_or_control) == cmd_or_control)) {
        return command.Command.Quit;
    }

    if ((key == GLFW_KEY_D) and (action == GLFW_PRESS) and ((mods & GLFW_MOD_ALT) == GLFW_MOD_ALT)) {
        return command.Command.ToggleDebug;
    }

    return null;
}

// fn character_typed(window: ?*GLFWwindow, char: c_uint) callconv(.C) void {
//     const cmd = command.Command{ .TypeCharacter = @intCast(u8, char) };
//     editor.process_command(cmd) catch unreachable;
// }

fn key_typed(window: ?*GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const cmd = key_to_cmd(key, action, mods);

    if (cmd) |cmd_to_run| {
        game.process_command(cmd_to_run);
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = &gpa.allocator;

    if (glfwInit() == 0) {
        console.debug("GLFW didn't init!\n", .{});
        std.os.exit(1);
    }

    glfwWindowHint(GLFW_SAMPLES, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    var window = glfwCreateWindow(1920, 1080, "base_code", null, null);
    if (@ptrToInt(window) == 0) {
        console.debug("ERROR: could not open a window\n", .{});
        glfwTerminate();
        std.os.exit(1);
    }
    defer glfwDestroyWindow(window);

    // _ = glfwSetCharCallback(window, character_typed);
    _ = glfwSetKeyCallback(window, key_typed);

    glfwMakeContextCurrent(window);

    var open_gl: OpenGL = undefined;
    try get_opengl_funcs(allocator, &open_gl, OpenGL);
    open_gl.init();
    open_gl.print_info();
    var renderer = try opengl_renderer.Renderer.init(allocator, &open_gl);
    defer renderer.deinit();

    {
        var viewport = [_]c_int{ 0, 0, 0, 0 };
        glfwGetFramebufferSize(window, &viewport[2], &viewport[3]);
        renderer.set_viewport(viewport);
    }

    game = try Game.new(allocator, &renderer);
    glfwSwapInterval(1);

    const renderer_info = open_gl.glGetString(GL_RENDERER);
    const version = open_gl.glGetString(GL_VERSION);
    console.debug("Renderer info: {s}\n", .{renderer_info});
    console.debug("OpenGL version supported: {s}\n", .{version});

    open_gl.glEnable(GL_DEPTH_TEST);
    open_gl.glDepthFunc(GL_LESS);

    var previous_frame_time: f64 = glfwGetTime();

    while (glfwWindowShouldClose(window) == 0) {
        var viewport = [_]c_int{ 0, 0, 0, 0 };
        glfwGetFramebufferSize(window, &viewport[2], &viewport[3]);
        renderer.set_viewport(viewport);

        const frame_time = glfwGetTime();
        const dt = frame_time - previous_frame_time;
        previous_frame_time = frame_time;

        {
            // Render stuff now
            game.prepare_render(dt);
            try renderer.render();
        }

        glfwSwapBuffers(window);

        // TODO: fix the stretching screen issue by rendering immediately after a resize
        glfwPollEvents();

        if (!game.running) {
            glfwSetWindowShouldClose(window, 1);
        }

        // if (gpa.detectLeaks()) {
        //     console.debug("memory leak\n", .{});
        // }
    }

    console.debug("Closing game\n", .{});

    glfwTerminate();
}
