const std = @import("std");
const console = @import("console.zig");

const resources = struct {
    const @"floor_tiles.png" = @embedFile("../assets/floor_tiles.png");
};

pub const Resource = struct {
    file_name: []const u8,
    data: [*]const u8,
    length: usize,
    texture_id: c_uint,

    pub fn find(name: []const u8) ?Resource {
        inline for (std.meta.declarations(resources)) |decl| {
            if (std.mem.eql(u8, name, decl.name)) {
                return Resource{
                    .file_name = decl.name,
                    .data = @field(resources, decl.name),
                    .length = @field(resources, decl.name).len,
                    .texture_id = 0,
                };
            }
        }
        console.debug("{} not found\n", .{name});
        return null;
    }
};
