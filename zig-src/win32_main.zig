const std = @import("std");
usingnamespace @import("std").os.windows;
const glfw = @import("glfw_main.zig");

const MB_OK: UINT = 0x0;
const MB_ICONERROR: UINT = 0x10;

pub extern "user32" fn MessageBoxA(hWnd: ?HWND, lpText: LPCSTR, lpCaption: ?LPCSTR, uType: UINT) callconv(.Stdcall) INT;

pub export fn windows_main_shim() void {
    _ = glfw.main() catch |err| {
        var buf = [_:0]u8{0} ** 64;
        _ = std.fmt.bufPrint(buf[0..], "Error: {}", .{@errorName(err)}) catch "Error"[0..];
        _ = MessageBoxA(null, &buf, null, MB_OK | MB_ICONERROR);
    };
}

pub export fn win_main(hInstance: HINSTANCE, hPrevInstance: ?HINSTANCE, lpCmdLine: PWSTR, nCmdShow: INT) callconv(.C) INT {
    windows_main_shim();
    return 0;
}

pub export fn main() void {
    windows_main_shim();
}

comptime {
    // I have no idea why this is necessary, Zig seems to be very confused about WinMain
    // So we need this nonsense so this can be build in Release or Debug mode
    if (std.builtin.mode != .Debug) {
        @export(win_main, .{ .name = "wWinMain" });
    }
}
