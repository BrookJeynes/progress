const std = @import("std");
const bar = @import("bar.zig");
const ansi_term = @import("ansi-term.zig");
const Bar = bar.Bar;
const Config = bar.Config;

pub const MultiBar = struct {
    bars: std.ArrayList(*Bar),
    writer: *std.Io.File.Writer,
    mutex: std.Io.Mutex,
    allocator: std.mem.Allocator,
    active_line: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        writer: *std.Io.File.Writer,
    ) MultiBar {
        return .{
            .bars = .empty,
            .writer = writer,
            .mutex = std.Io.Mutex.init,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MultiBar) void {
        ansi_term.showCursor(&self.writer.interface) catch {};
        self.writer.interface.flush() catch {};
        self.bars.deinit(self.allocator);
    }

    pub fn addBar(self: *MultiBar, max_progress: usize, config: Config) !*Bar {
        var safe_config = config;
        safe_config.write_newline_on_finish = false;

        const new_pb = try self.allocator.create(Bar);
        new_pb.* = Bar.init(max_progress, self.writer, safe_config);
        try self.bars.append(self.allocator, new_pb);
        try self.writer.interface.writeAll("\n");
        self.active_line += 1;
        return new_pb;
    }

    pub fn render(self: *MultiBar) !void {
        self.mutex.lockUncancelable(self.writer.io);
        defer self.mutex.unlock(self.writer.io);

        if (self.active_line == 0) return;

        try ansi_term.cursorUp(&self.writer.interface, self.active_line);

        var newly_active: usize = 0;

        for (self.bars.items) |pb| {
            if (pb.isFinished() and pb.config.clear_on_finish) {
                continue;
            }

            try ansi_term.clearCurrentLine(&self.writer.interface);
            try pb.render();
            try ansi_term.cursorDown(&self.writer.interface, 1);
            try ansi_term.setCursorColumn(&self.writer.interface, 0);

            newly_active += 1;
        }

        if (newly_active == 0) {
            try ansi_term.showCursor(&self.writer.interface);
        }

        if (newly_active < self.active_line) {
            const diff = self.active_line - newly_active;
            for (0..diff) |_| {
                try ansi_term.clearCurrentLine(&self.writer.interface);
                try ansi_term.cursorDown(&self.writer.interface, 1);
            }
            try ansi_term.cursorUp(&self.writer.interface, diff);
        }

        self.active_line = newly_active;
    }
};
