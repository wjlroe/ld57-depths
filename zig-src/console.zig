const std = @import("std");
const windows = std.os.windows;

// We need an error version of this that'll pop up a window
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (std.builtin.os.tag == .windows) {
        _ = windows.GetStdHandle(windows.STD_ERROR_HANDLE) catch |err| {
            return;
        };
    }

    std.debug.warn(fmt, args);
}
