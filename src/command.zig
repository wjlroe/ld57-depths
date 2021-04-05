pub const CommandTag = enum {
    ToggleDebug,
    Quit,
    LeftClick,
    Up,
    Down,
    Left,
    Right,
    Enter,
};

pub const Command = union(CommandTag) {
    ToggleDebug: void,
    Quit: void,
    LeftClick: void,
    Up: void,
    Down: void,
    Left: void,
    Right: void,
    Enter: void,
};
