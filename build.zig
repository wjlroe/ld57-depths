const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");
const LibExeObjStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const os = target.os_tag orelse builtin.os.tag;

    var main_file: []const u8 = undefined;
    if (os == .windows) {
        main_file = "src/win32_main.zig";
    } else {
        main_file = "src/glfw_main.zig";
    }

    const exe = b.addExecutable("base_code", main_file);

    exe.addIncludeDir("include");
    exe.addCSourceFile("src/truetype.c", &[_][]const u8{"-std=c99"});
    exe.addCSourceFile("include/fast_obj-1.1/fast_obj.c", &[_][]const u8{"-std=c99"});

    exe.linkLibC();

    exe.linkSystemLibrary("glfw3");

    switch (os) {
        .windows => {
            exe.addIncludeDir("C:/dev/GLFW/glfw-3.3.4.bin.WIN64/include");
            exe.addLibPath("C:/dev/GLFW/glfw-3.3.4.bin.WIN64/lib-vc2019");
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("shell32");
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
            exe.subsystem = switch (mode) {
                .Debug => .Console,
                else => .Windows,
            };
        },
        .macos => {
            exe.addIncludeDir("/opt/X11/include");
            exe.addFrameworkDir("/System/Library/Frameworks");
            exe.linkFramework("OpenGL");
            exe.linkFramework("Cocoa");
            exe.addLibPath("vendor/glfw-3.3.2/mac");
        },
        .linux => {
            exe.addIncludeDir("/usr/include");
            exe.addIncludeDir("/usr/X11/include");
            exe.addLibPath("vendor/glfw-3.3.2/linux");
            exe.addLibPath("/usr/lib");
            exe.addLibPath("/usr/X11/lib");
            exe.addLibPath("/opt/X11/lib");
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("GL");
        },
        else => {},
    }

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run library tests");

    const tests = b.addTest("src/tests.zig");
    tests.setBuildMode(mode);
    tests.linkSystemLibrary("c");

    test_step.dependOn(&tests.step);
}
