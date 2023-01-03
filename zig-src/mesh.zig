const std = @import("std");
const c = @import("c.zig");

pub fn load_mesh(filename: [*c]const u8) void {
    const mesh: *c.fastObjMesh = c.fast_obj_read(filename);
    {
        var pos_idx: c_uint = 0;
        std.debug.warn("type of mesh.positions: {}\n", .{@typeName(@TypeOf(mesh.positions))});
        while (pos_idx < mesh.position_count) {
            std.debug.warn("pos at idx: {}: {}\n", .{pos_idx, mesh.positions[pos_idx]});
            pos_idx += 1;
        }
    }
    defer c.fast_obj_destroy(mesh);
}
