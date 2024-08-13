const std = @import("std");
const termsize = @import("termsize.zig");
const escape_codes = @import("escape_codes.zig");

const Error = error{
    FailedToRender,
    ///Used when the progress bar is too small to render all the content.
    BarTooSmall,
};

///Used when the terminal width cannot be retrieved.
const default_bar_width: u16 = 40;

const Config = struct {
    ///Progress bar description.
    description: ?[]const u8 = null,
    ///The progress bar prefix.
    bar_prefix: u8 = '|',
    ///The progress bar suffix.
    bar_suffix: u8 = '|',
    ///The charater to fill the progress bar with.
    bar_fill_char: u8 = '#',
    ///Show the iteration count.
    show_iterations: bool = false,
    ///Show the percentage.
    show_percentage: bool = false,
    ///Clear the line when the progress bar finishes.
    clear_on_finish: bool = false,
    ///Write a newline when the progress bar finishes.
    write_newline_on_finish: bool = true,
    ///Custom progress bar width.
    ///If the width is greater than the terminal width, the terminal width will be used.
    ///It is up to you to ensure you provide enough space to render the complete bar. If the bar is too small, calls to `render()` will error.
    width: ?usize = null,
};

const ProgressBar = @This();

current_progress: usize = 0,
max_progress: usize = 0,
bw: std.io.BufferedWriter(4096, std.io.AnyWriter),
config: Config,
mutex: std.Thread.Mutex = std.Thread.Mutex{},
///Direct access is not thread safe. Use `isFinished()` if you need thread safety.
finished: bool = false,

pub fn init(max_progress: usize, writer: std.io.AnyWriter, config: Config) ProgressBar {
    return ProgressBar{
        .max_progress = max_progress,
        .bw = std.io.bufferedWriter(writer),
        .config = config,
    };
}

///Add `num` to the progress bar.
///If `num` is greater than `max_progress`, `current_progress` will be set to the max.
pub fn add(self: *ProgressBar, num: usize) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    if (self.current_progress + num < self.max_progress) {
        self.current_progress += num;
    } else {
        self.current_progress = self.max_progress;
    }
}

///Render the progress bar. The progress bar must have a `max_progress` greater than 0.
pub fn render(self: *ProgressBar) !void {
    const winsize = try termsize.termSize(std.io.getStdOut()) orelse termsize.TermSize{ .width = default_bar_width, .height = 0 };
    const width = if (self.config.width) |w| @min(w, winsize.width) else winsize.width;

    self.mutex.lock();
    defer self.mutex.unlock();

    if (self.finished) return;

    try self.clear();

    const percentage = @as(f32, @floatFromInt(self.current_progress)) / @as(f32, @floatFromInt(self.max_progress));
    var padding: usize = 0;

    const extra_front_chars = brk: {
        var count: usize = 0;

        if (self.config.description) |desc| {
            count += (desc.len + 3); // "{desc} ||"
        } else {
            count += 2; // "||"
        }

        if (self.config.show_percentage) count += 4; // "xxx%"

        break :brk count;
    };

    const extra_back_chars = brk: {
        var count: usize = 0;

        if (self.config.show_iterations) {
            padding += 2; // Add spacing after width.
            const num_len: usize = @intFromFloat(@ceil(@log10(@as(f32, @floatFromInt(self.max_progress + 1)))));

            count += 8 + (num_len * 2); // "[ {num_len} / {num_len} ]"
            try escape_codes.setCursorColumn(self.bw.writer(), std.math.sub(usize, width + padding, count) catch return Error.BarTooSmall);

            _ = try self.bw.writer().print("[ {[curr]: >[padding]} / {[max]} ]\r", .{ .curr = self.current_progress, .padding = num_len, .max = self.max_progress });
        }

        break :brk count;
    };

    const extra_chars = extra_front_chars + extra_back_chars + padding;
    if (extra_chars > width) return Error.BarTooSmall;

    if (self.config.description) |desc| {
        try self.bw.writer().print("{s}", .{desc});
        try escape_codes.cursorForward(self.bw.writer(), 1);
    }

    if (self.config.show_percentage) {
        try self.bw.writer().print("{d: >3}%", .{@as(u32, @intFromFloat(percentage * 100))});
        try escape_codes.cursorForward(self.bw.writer(), 1);
    }

    _ = try self.bw.writer().writeByte(self.config.bar_prefix);

    const range: usize = @intFromFloat(percentage * @as(f32, @floatFromInt(std.math.sub(usize, width, extra_front_chars + extra_back_chars) catch 0)));
    for (0..range) |_| {
        _ = try self.bw.writer().writeByte(self.config.bar_fill_char);
    }

    try escape_codes.hideCursor(self.bw.writer());
    try escape_codes.setCursorColumn(self.bw.writer(), width - extra_back_chars);

    _ = try self.bw.writer().writeByte(self.config.bar_suffix);

    if (self.current_progress >= self.max_progress and !self.finished) {
        self.finished = true;

        if (self.config.clear_on_finish) try self.clear();
        if (self.config.write_newline_on_finish) _ = try self.bw.write("\n");
        try escape_codes.showCursor(self.bw.writer());
    }

    try self.bw.flush();
}

///Returns `true` if the progress bar is finished and `false` otherwise.
pub fn isFinished(self: *ProgressBar) bool {
    self.mutex.lock();
    defer self.mutex.unlock();

    return self.current_progress >= self.max_progress or self.finished;
}

///Finish the progress bar.
pub fn finish(self: *ProgressBar) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.finished = true;
    self.current_progress = self.max_progress;

    try escape_codes.showCursor(self.bw.writer());
    try self.bw.flush();
}

///Reset the progress bar.
pub fn reset(self: *ProgressBar) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.finished = false;
    self.current_progress = 0;
}

///Set the progress bar to `num`.
///
///If `num` is equal to `max_progress`, `finished` is set true.
///If `num` is greater than `max_progress`, `current_progress` will be set to the max.
pub fn set(self: *ProgressBar, num: usize) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    if (num >= self.max_progress) {
        self.finished = true;
        self.current_progress = self.max_progress;
        return;
    }

    self.current_progress = num;
}

///Update the description.
pub fn update_description(self: *ProgressBar, description: []const u8) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.config.description = description;
}

///Clear the progress bar.
///
///This function is not thread safe.
pub fn clear(self: *ProgressBar) !void {
    try escape_codes.clearCurrentLine(self.bw.writer());
    try escape_codes.setCursorColumn(self.bw.writer(), 0);
    try self.bw.flush();
}
