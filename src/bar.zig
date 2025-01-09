const std = @import("std");
const termsize = @import("termsize.zig");
const ansi_term = @import("ansi-term.zig");

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
    bar_prefix: u21 = '|',
    ///The progress bar suffix.
    bar_suffix: u21 = '|',
    ///The charater to fill the progress bar with.
    bar_fill_char: u21 = '#',
    ///Show the iteration count.
    show_iterations: bool = false,
    ///Show the progress bar background.
    show_background: bool = false,
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

const Bar = @This();

///Direct access is not thread safe. Use `currentProgress()` if you need thread safety.
current_progress: usize = 0,
max_progress: usize = 0,
bw: std.io.BufferedWriter(4096, std.io.AnyWriter),
config: Config,
mutex: std.Thread.Mutex = std.Thread.Mutex{},
///Direct access is not thread safe. Use `isFinished()` if you need thread safety.
finished: bool = false,
///The progress bar foreground colour.
colour: ansi_term.Colour = .Default,
///The progress bar background colour.
bg_colour: ansi_term.Colour = .Default,

pub fn init(max_progress: usize, writer: std.io.AnyWriter, config: Config) Bar {
    return Bar{
        .max_progress = max_progress,
        .bw = std.io.bufferedWriter(writer),
        .config = config,
    };
}

///Add `num` to the progress bar.
///If `num` is greater than `max_progress`, `current_progress` will be set to the max.
pub fn add(self: *Bar, num: usize) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    if (self.current_progress + num < self.max_progress) {
        self.current_progress += num;
    } else {
        self.current_progress = self.max_progress;
    }
}

///Render the progress bar.
pub fn render(self: *Bar) !void {
    const winsize = try termsize.termSize(std.io.getStdOut()) orelse termsize.TermSize{ .width = default_bar_width, .height = 0 };
    const width = if (self.config.width) |w| @min(w, winsize.width) else winsize.width;
    var unicode_conversion_buf: [8]u8 = undefined;

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
            try ansi_term.setCursorColumn(self.bw.writer(), std.math.sub(usize, width + padding, count) catch return Error.BarTooSmall);

            _ = try self.bw.writer().print("[ {[curr]: >[padding]} / {[max]} ]\r", .{ .curr = self.current_progress, .padding = num_len, .max = self.max_progress });
        }

        break :brk count;
    };

    const extra_chars = extra_front_chars + extra_back_chars + padding;
    if (extra_chars > width) return Error.BarTooSmall;

    if (self.config.description) |desc| {
        _ = try self.bw.write(desc);
        try ansi_term.cursorForward(self.bw.writer(), 1);
    }

    if (self.config.show_percentage) {
        try self.bw.writer().print("{d: >3}%", .{@as(u32, @intFromFloat(percentage * 100))});
        try ansi_term.cursorForward(self.bw.writer(), 1);
    }

    const prefix_bytes = try std.unicode.utf8Encode(self.config.bar_prefix, &unicode_conversion_buf);
    _ = try self.bw.write(unicode_conversion_buf[0..prefix_bytes]);

    const max_percentage_pos: usize = std.math.sub(usize, width, extra_front_chars + extra_back_chars) catch 0;
    const current_percentage_pos: usize = @intFromFloat(percentage * @as(f32, @floatFromInt(std.math.sub(usize, width, extra_front_chars + extra_back_chars) catch 0)));
    for (0..max_percentage_pos) |write_pos| {
        if (write_pos > current_percentage_pos) {
            if (self.config.show_background) {
                try ansi_term.writeColour(self.bw.writer(), self.bg_colour);
                const fill_char_bytes = try std.unicode.utf8Encode(self.config.bar_fill_char, &unicode_conversion_buf);
                _ = try self.bw.write(unicode_conversion_buf[0..fill_char_bytes]);
                try ansi_term.resetColour(self.bw.writer());
            }
            continue;
        }

        try ansi_term.writeColour(self.bw.writer(), self.colour);
        const fill_char_bytes = try std.unicode.utf8Encode(self.config.bar_fill_char, &unicode_conversion_buf);
        _ = try self.bw.write(unicode_conversion_buf[0..fill_char_bytes]);
        try ansi_term.resetColour(self.bw.writer());
    }

    try ansi_term.hideCursor(self.bw.writer());
    try ansi_term.setCursorColumn(self.bw.writer(), width - extra_back_chars);

    const suffix_bytes = try std.unicode.utf8Encode(self.config.bar_suffix, &unicode_conversion_buf);
    _ = try self.bw.write(unicode_conversion_buf[0..suffix_bytes]);

    if (self.current_progress >= self.max_progress and !self.finished) {
        self.finished = true;

        if (self.config.clear_on_finish) try self.clear();
        if (self.config.write_newline_on_finish) _ = try self.bw.write("\n");
        try ansi_term.showCursor(self.bw.writer());
    }

    try self.bw.flush();
}

///Set the progress bar colour.
pub fn setColour(self: *Bar, colour: ansi_term.Colour) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.colour = colour;
}

///Set the progress bar background colour.
pub fn setBgColour(self: *Bar, colour: ansi_term.Colour) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.bg_colour = colour;
}

///Show the progress bar background.
pub fn showBg(self: *Bar) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.config.show_background = true;
}

///Hide the progress bar background.
pub fn hideBg(self: *Bar) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.config.show_background = false;
}

///Returns `true` if the progress bar is finished and `false` otherwise.
pub fn isFinished(self: *Bar) bool {
    self.mutex.lock();
    defer self.mutex.unlock();

    return self.current_progress >= self.max_progress or self.finished;
}

///Returns the current progress.
pub fn currentProgress(self: *Bar) usize {
    self.mutex.lock();
    defer self.mutex.unlock();

    return self.current_progress;
}

///Finish the progress bar.
pub fn finish(self: *Bar) !void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.finished = true;
    self.current_progress = self.max_progress;

    try ansi_term.showCursor(self.bw.writer());
    try self.bw.flush();
}

///Reset the progress bar.
pub fn reset(self: *Bar) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.finished = false;
    self.current_progress = 0;
}

///Set the progress bar to `num`.
///
///If `num` is equal to `max_progress`, `finished` is set true.
///If `num` is greater than `max_progress`, `current_progress` will be set to the max.
pub fn set(self: *Bar, num: usize) void {
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
pub fn updateDescription(self: *Bar, description: []const u8) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.config.description = description;
}

///Clear the progress bar.
///
///This function is not thread safe.
pub fn clear(self: *Bar) !void {
    try ansi_term.clearCurrentLine(self.bw.writer());
    try ansi_term.setCursorColumn(self.bw.writer(), 0);
    try self.bw.flush();
}
