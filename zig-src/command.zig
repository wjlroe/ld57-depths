pub const CommandTag = enum {
    ToggleDebug,
    Quit,
    LeftClick,
    Up,
    Down,
    Left,
    Right,
    Enter,
    StartGame,
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
    StartGame: void,
};
