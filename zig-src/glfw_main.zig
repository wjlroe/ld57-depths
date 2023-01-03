const std = @import("std");
const opengl_renderer = @import("opengl_renderer.zig");
usingnamespace @import("opengl.zig");
usingnamespace @import("c.zig");
const console = @import("console.zig");
const command = @import("command.zig");
const Game = @import("game.zig").Game;

pub var game: *Game = undefined;

const cmd_or_control = if (std.builtin.os.tag == .macos) GLFW_MOD_SUPER else GLFW_MOD_CONTROL;

fn get_opengl_funcs_internal(allocator: *std.mem.Allocator, comptime T: type, open_gl: *T) !void {
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

fn get_opengl_funcs(allocator: *std.mem.Allocator, comptime T: type, open_gl: *OpenGL) !void {
    try get_opengl_funcs_internal(allocator, T, open_gl);

    comptime var name_buffer: [64]u8 = undefined;
    inline for (gl_versions) |gl_version, i| {
        if (open_gl.is_version_supported(gl_version)) {
            comptime const gl_struct = gl_structs[i];
            var opengl_gl_sub: gl_struct = undefined;
            try get_opengl_funcs_internal(allocator, gl_struct, &opengl_gl_sub);
            comptime const version_func_name = try std.fmt.bufPrint(name_buffer[0..], "gl_{}_{}_funcs", .{ gl_version[0], gl_version[1] });
            @field(open_gl, version_func_name) = opengl_gl_sub;
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

    if ((key == GLFW_KEY_S) and (action == GLFW_PRESS) and (mods == 0)) {
        return command.Command.Down;
    }

    if ((key == GLFW_KEY_W) and (action == GLFW_PRESS) and (mods == 0)) {
        return command.Command.Up;
    }

    if ((key == GLFW_KEY_DOWN) and (action == GLFW_PRESS) and (mods == 0)) {
        return command.Command.Down;
    }

    if ((key == GLFW_KEY_UP) and (action == GLFW_PRESS) and (mods == 0)) {
        return command.Command.Up;
    }

    if ((key == GLFW_KEY_ENTER) and (action == GLFW_PRESS) and (mods == 0)) {
        return command.Command.Enter;
    }

    return null;
}

fn mouse_to_cmd(button: c_int, action: c_int, mods: c_int) ?command.Command {
    if ((button == GLFW_MOUSE_BUTTON_LEFT) and (action == GLFW_PRESS) and ((mods == 0))) {
        return command.Command.LeftClick;
    }

    return null;
}

fn glfw_error_callback(error_code: c_int, description: [*c]const u8) callconv(.C) void {
    var error_code_value = std.ArrayList(u8).init(std.heap.c_allocator);
    switch (error_code) {
        GLFW_API_UNAVAILABLE => {
            error_code_value.appendSlice("GLFW_API_UNAVAILABLE") catch unreachable;
        },
        GLFW_FORMAT_UNAVAILABLE => {
            error_code_value.appendSlice("GLFW_FORMAT_UNAVAILABLE") catch unreachable;
        },
        GLFW_INVALID_ENUM => {
            error_code_value.appendSlice("GLFW_INVALID_ENUM") catch unreachable;
        },
        GLFW_INVALID_VALUE => {
            error_code_value.appendSlice("GLFW_INVALID_VALUE") catch unreachable;
        },
        GLFW_NO_CURRENT_CONTEXT => {
            error_code_value.appendSlice("GLFW_NO_CURRENT_CONTEXT") catch unreachable;
        },
        GLFW_NOT_INITIALIZED => {
            error_code_value.appendSlice("GLFW_NOT_INITIALIZED") catch unreachable;
        },
        GLFW_OUT_OF_MEMORY => {
            error_code_value.appendSlice("GLFW_OUT_OF_MEMORY") catch unreachable;
        },
        GLFW_PLATFORM_ERROR => {
            error_code_value.appendSlice("GLFW_PLATFORM_ERROR") catch unreachable;
        },
        GLFW_VERSION_UNAVAILABLE => {
            error_code_value.appendSlice("GLFW_VERSION_UNAVAILABLE") catch unreachable;
        },
        else => {
            error_code_value.appendSlice("UNKNOWN") catch unreachable;
        },
    }
    std.debug.warn("GLFW error: {} ({}): {s}\n", .{ error_code, error_code_value.items, description });
}

// fn character_typed(window: ?*GLFWwindow, char: c_uint) callconv(.C) void {
//     const cmd = command.Command{ .TypeCharacter = @intCast(u8, char) };
//     game.process_command(cmd) catch unreachable;
// }

fn key_typed(window: ?*GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const cmd = key_to_cmd(key, action, mods);

    if (cmd) |cmd_to_run| {
        game.process_command(cmd_to_run);
    }
}

fn cursor_position_changed(window: ?*GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    game.update_mouse_position(xpos, ypos);
}

fn mouse_button_clicked(window: ?*GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const cmd = mouse_to_cmd(button, action, mods);

    if (cmd) |cmd_to_run| {
        game.process_command(cmd_to_run);
    }
}

fn create_window(open_gl: *OpenGL) ?*GLFWwindow {
    var window: ?*GLFWwindow = undefined;
    const try_gl_versions = [_][2]c_int{ .{ 4, 3 }, .{ 4, 1 }, .{ 3, 2 } };

    for (try_gl_versions) |gl_version| {
        glfwWindowHint(GLFW_SAMPLES, 4);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, gl_version[0]);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, gl_version[1]);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHintString(GLFW_X11_CLASS_NAME, "Game");

        window = glfwCreateWindow(1920, 1080, "base_code", null, null);
        if (@ptrToInt(window) != 0) {
            console.debug("OpenGL version available: {}.{}\n", .{ gl_version[0], gl_version[1] });
            open_gl.gl_version = gl_version;
            break;
        }
    }
    return window;
}

pub fn main() anyerror!void {
    // safety = true ; <- print out if there were memory leaks
    // Not useful since it doesn't print what memory was leaked!
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }){};
    var allocator = &gpa.allocator;
    defer {
        _ = gpa.deinit();
    }

    _ = glfwSetErrorCallback(glfw_error_callback);

    if (glfwInit() == 0) {
        console.debug("GLFW didn't init!\n", .{});
        std.os.exit(1);
    }

    var open_gl: OpenGL = undefined;
    var window = create_window(&open_gl);
    if (@ptrToInt(window) == 0) {
        console.debug("ERROR: could not open a window\n", .{});
        glfwTerminate();
        std.os.exit(1);
    }
    defer glfwDestroyWindow(window);

    // _ = glfwSetCharCallback(window, character_typed);
    _ = glfwSetKeyCallback(window, key_typed);
    _ = glfwSetCursorPosCallback(window, cursor_position_changed);
    _ = glfwSetMouseButtonCallback(window, mouse_button_clicked);

    glfwMakeContextCurrent(window);

    try get_opengl_funcs(allocator, OpenGL, &open_gl);
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
    defer game.deinit();
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

    glfwTerminate();
    console.debug("Closing game\n", .{});
}
