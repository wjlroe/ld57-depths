const std = @import("std");
const Rect = @import("rect.zig").Rect;

pub fn layout_vertically(rects: []*Rect, padding: f32) void {
    var y_offset: f32 = 0.0;
    for (rects) |rect| {
        rect.center[1] += y_offset;
        y_offset += rect.bounds[1];
        y_offset += padding;
    }
}

pub fn layout_horizontally(rects: []*Rect, padding: f32) void {
    var x_offset: f32 = 0.0;
    for (rects) |rect| {
        rect.center[0] += x_offset;
        x_offset += rect.bounds[0];
        x_offset += padding;
    }
}

pub fn center_vertically(rects: []*Rect, within: Rect) void {
    var content_height: f32 = 0.0;
    for (rects) |rect| {
        content_height += rect.bounds[1];
    }
    const push_down = (within.bounds[1] / 2.0) - (content_height / 2.0);
    for (rects) |rect| {
        rect.center[1] += push_down;
    }
}

pub fn center_horizontally(rects: []*Rect, within: Rect) void {
    // TODO: this won't work for horizontally aligned rects, it assumes vertical layout...
    const middle_x = within.center[0];
    for (rects) |rect| {
        rect.center[0] = middle_x;
    }
}
