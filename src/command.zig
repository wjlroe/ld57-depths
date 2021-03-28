pub const CommandTag = enum {
    ToggleDebug,
    Quit,
};

pub const Command = union(CommandTag) {
    ToggleDebug: void,
    Quit: void,
};
