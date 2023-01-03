const std = @import("std");

pub const CompileError = struct {
    line: usize = 0,
    column: usize = 0,
    message: []const u8 = "No Error",
};

pub const ShaderSource = struct {
    source: []const u8,
    filename: []const u8,

    pub fn init(comptime filename: []const u8) ShaderSource {
        return ShaderSource{
            .source = @embedFile(filename)[0..],
            .filename = filename,
        };
    }

    pub fn c_str(self: *const ShaderSource, allocator: *std.mem.Allocator) ![]u8 {
        return std.cstr.addNullByte(allocator, self.source);
    }

    pub fn print_source(self: *const ShaderSource, allocator: *std.mem.Allocator, errors: []const CompileError) ![]u8 {
        var lines = std.ArrayList([]const u8).init(allocator);
        var current_line = std.ArrayList(u8).init(allocator);
        for (self.source) |shader_c| {
            if (shader_c == '\n') {
                try lines.append(current_line.toOwnedSlice());
                try current_line.resize(0);
            } else {
                try current_line.append(shader_c);
            }
        }
        if (current_line.items.len > 0) {
            try lines.append(current_line.items);
        }
        const line_width = num_decimals(lines.items.len);

        var output = std.ArrayList(u8).init(allocator);
        const fmt_options = std.fmt.FormatOptions{ .width = line_width, .fill = ' ', .alignment = std.fmt.Alignment.Right };
        var line_num: usize = 0;
        for (lines.items) |line| {
            line_num += 1;
            var line_is_error: bool = false;
            for (errors) |compile_error| {
                if (compile_error.line == line_num) {
                    line_is_error = true;
                    try output.appendSlice("> ");
                }
            }
            if (!line_is_error) {
                try output.appendSlice("  ");
            }
            try std.fmt.formatIntValue(line_num, "d", fmt_options, output.outStream());
            try output.appendSlice(": ");
            try output.appendSlice(line);
            try output.append('\n');
        }
        return output.items;
    }
};

fn num_decimals(value: usize) usize {
    var decimals: usize = 0;
    var num: usize = 1;
    while (num < value) {
        decimals += 1;
        num *= 10;
    }
    return decimals;
}
