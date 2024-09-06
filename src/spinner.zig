const std = @import("std");
const termsize = @import("termsize.zig");
const escape_codes = @import("escape_codes.zig");

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

bw: std.io.BufferedWriter(4096, std.io.AnyWriter),
config: Config,
mutex: std.Thread.Mutex = std.Thread.Mutex{},
///Direct access is not thread safe. Use `isFinished()` if you need thread safety.
finished: bool = false,
current_symbol_idx: usize = 0,

pub fn init(writer: std.io.AnyWriter, config: Config) Spinner {
    return Spinner{
        .bw = std.io.bufferedWriter(writer),
        .config = config,
    };
}

fn renderComplete(self: *Spinner, completion_char: u21) !void {
    try self.clear();
    var buf: [8]u8 = undefined;
    const bytes = try std.unicode.utf8Encode(completion_char, &buf);
    _ = try self.bw.write(buf[0..bytes]);

    if (self.config.description) |desc| {
        try escape_codes.cursorForward(self.bw.writer(), 1);
        _ = try self.bw.write(desc);
    }

    try self.bw.flush();
}

///Render the progress spinner and advance a visual cycle.
pub fn render(self: *Spinner) !void {
    self.mutex.lock();
    defer self.mutex.unlock();

    if (self.finished) return;

    try self.clear();
    try escape_codes.hideCursor(self.bw.writer());

    var buf: [8]u8 = undefined;
    const bytes = try std.unicode.utf8Encode(self.config.symbols[self.current_symbol_idx], &buf);
    _ = try self.bw.write(buf[0..bytes]);

    if (self.config.description) |desc| {
        try escape_codes.cursorForward(self.bw.writer(), 1);
        _ = try self.bw.write(desc);
    }

    try self.bw.flush();
    self.current_symbol_idx = (self.current_symbol_idx + 1) % self.config.symbols.len;
}

///Returns `true` if the progress spinner is finished and `false` otherwise.
pub fn isFinished(self: *Spinner) bool {
    self.mutex.lock();
    defer self.mutex.unlock();

    return self.finished;
}

///Finish the progress spinner.
pub fn finish(self: *Spinner) !void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.finished = true;

    if (self.config.completion_character) |char| {
        try self.renderComplete(char);
    }

    if (self.config.clear_on_finish) try self.clear();
    if (self.config.write_newline_on_finish) _ = try self.bw.write("\n");

    try escape_codes.showCursor(self.bw.writer());
    try self.bw.flush();
}

///Update the description.
pub fn updateDescription(self: *Spinner, description: []const u8) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.config.description = description;
}

///Update the description and continue the spinner on a newline.
pub fn updateDescriptionNewline(self: *Spinner, description: []const u8) !void {
    self.mutex.lock();
    defer self.mutex.unlock();

    if (self.config.completion_character) |char| {
        try self.renderComplete(char);
    }

    self.config.description = description;

    _ = try self.bw.write("\n");
    try self.bw.flush();
}

///Clear the progress spinner.
///
///This function is not thread safe.
pub fn clear(self: *Spinner) !void {
    try escape_codes.clearCurrentLine(self.bw.writer());
    try escape_codes.setCursorColumn(self.bw.writer(), 0);
    try self.bw.flush();
}
