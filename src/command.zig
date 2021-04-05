pub const CommandTag = enum {
    ToggleDebug,
    Quit,
    LeftClick,
};

pub const Command = union(CommandTag) {
    ToggleDebug: void,
    Quit: void,
    LeftClick: void,
};
