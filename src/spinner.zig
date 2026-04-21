const std = @import("std");
const ansi_term = @import("ansi-term.zig");

pub const PredefinedSymbols = enum {
    ///- \ | /
    pub const default: []const u21 = &[_]u21{ '-', '\\', '|', '/' };
    ///⎺ ⎻ ⎼ ⎽ ⎼ ⎻
    pub const line: []const u21 = &[_]u21{ '⎺', '⎻', '⎼', '⎽', '⎼', '⎻' };
    ///◑ ◒ ◐ ◓
    pub const moon: []const u21 = &[_]u21{ '◑', '◒', '◐', '◓' };
    ///◷ ◶ ◵ ◴
    pub const pie: []const u21 = &[_]u21{ '◷', '◶', '◵', '◴' };
    ///⣾ ⣷ ⣯ ⣟ ⡿ ⢿ ⣻ ⣽
    pub const pixel: []const u21 = &[_]u21{ '⣾', '⣷', '⣯', '⣟', '⡿', '⢿', '⣻', '⣽' };
};

const Config = struct {
    ///Progress spinner description.
    description: ?[]const u8 = null,
    symbols: []const u21 = PredefinedSymbols.default,
    ///Clear the line when the progress spinner finishes.
    clear_on_finish: bool = false,
    ///Write a newline when the progress spinner finishes.
    write_newline_on_finish: bool = true,
    ///Character to write on completion.
    completion_character: ?u21 = null,
};

const Spinner = @This();

writer: *std.Io.File.Writer,
config: Config,
mutex: std.Io.Mutex = std.Io.Mutex.init,
///Direct access is not thread safe. Use `isFinished()` if you need thread safety.
finished: bool = false,
current_symbol_idx: usize = 0,

pub fn init(writer: *std.Io.File.Writer, config: Config) Spinner {
    return Spinner{
        .writer = writer,
        .config = config,
    };
}

fn renderComplete(self: *Spinner, completion_char: u21) !void {
    try self.clear();
    var buf: [8]u8 = undefined;
    const bytes = try std.unicode.utf8Encode(completion_char, &buf);
    try self.writer.interface.writeAll(buf[0..bytes]);

    if (self.config.description) |desc| {
        try ansi_term.cursorForward(&self.writer.interface, 1);
        try self.writer.interface.writeAll(desc);
    }

    if (self.config.clear_on_finish) try self.clear();

    try self.writer.interface.flush();
}

///Render the progress spinner and advance a visual cycle.
pub fn render(self: *Spinner) !void {
    try self.mutex.lock(self.writer.io);
    defer self.mutex.unlock(self.writer.io);

    if (self.finished) return;

    try self.clear();
    try ansi_term.hideCursor(&self.writer.interface);

    var buf: [8]u8 = undefined;
    const bytes = try std.unicode.utf8Encode(self.config.symbols[self.current_symbol_idx], &buf);
    try self.writer.interface.writeAll(buf[0..bytes]);

    if (self.config.description) |desc| {
        try ansi_term.cursorForward(&self.writer.interface, 1);
        try self.writer.interface.writeAll(desc);
    }

    try self.writer.interface.flush();
    self.current_symbol_idx = (self.current_symbol_idx + 1) % self.config.symbols.len;
}

///Returns `true` if the progress spinner is finished and `false` otherwise.
pub fn isFinished(self: *Spinner) bool {
    self.mutex.lockUncancelable(self.writer.io);
    defer self.mutex.unlock(self.writer.io);

    return self.finished;
}

///Finish the progress spinner.
pub fn finish(self: *Spinner) !void {
    try self.mutex.lock(self.writer.io);
    defer self.mutex.unlock(self.writer.io);

    self.finished = true;

    if (self.config.completion_character) |char| {
        try self.renderComplete(char);
    }

    if (self.config.clear_on_finish) try self.clear();
    if (self.config.write_newline_on_finish) try self.writer.interface.writeAll("\n");

    try ansi_term.showCursor(&self.writer.interface);
    try self.writer.interface.flush();
}

///Update the description.
pub fn updateDescription(self: *Spinner, description: []const u8) void {
    self.mutex.lockUncancelable(self.writer.io);
    defer self.mutex.unlock(self.writer.io);

    self.config.description = description;
}

///Update the description and continue the spinner on a newline.
pub fn updateDescriptionNewline(self: *Spinner, description: []const u8) !void {
    try self.mutex.lock(self.writer.io);
    defer self.mutex.unlock(self.writer.io);

    if (self.config.completion_character) |char| {
        try self.renderComplete(char);
    }

    self.config.description = description;

    try self.writer.interface.writeAll("\n");
    try self.writer.interface.flush();
}

///Clear the progress spinner.
///
///This function is not thread safe.
pub fn clear(self: *Spinner) !void {
    try ansi_term.clearCurrentLine(&self.writer.interface);
    try ansi_term.setCursorColumn(&self.writer.interface, 0);
    try self.writer.interface.flush();
}
