const std = @import("std");
const bar = @import("bar.zig");
const ansi_term = @import("ansi-term.zig");
const Bar = bar.Bar;
const Config = bar.Config;

pub const MultiBar = struct {
    bars: std.ArrayList(Bar),
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
        self.bars.deinit(self.allocator);
    }

    /// Returns the minimum buffer size in bytes needed to hold `n` bars.
    pub fn bufSize(n: usize) usize {
        return n * @sizeOf(Bar) + @alignOf(Bar) - 1;
    }

    /// Add a new progress bar to the manager.
    /// Overrides `write_newline_on_finish` to false to ensure terminal visual integrity.
    /// When statically backed, `error.OutOfMemory` will be returned when the bar limit is exceeded.
    /// Returns the index of the newly added bar.
    pub fn addBar(self: *MultiBar, max_progress: usize, config: Config) !usize {
        var safe_config = config;
        safe_config.write_newline_on_finish = false;

        const new_pb = Bar.init(max_progress, self.writer, safe_config);
        const index = self.bars.items.len;

        try self.bars.append(self.allocator, new_pb);
        try self.writer.interface.writeAll("\n");
        self.active_line += 1;
        return index;
    }

    /// Returns a pointer to the bar at the given index.
    /// Not thread safe. The caller is responsible for synchronization
    /// if the bar is accessed concurrently with `render()` or other threads.
    pub fn bar(self: *MultiBar, index: usize) !*Bar {
        if (index >= self.bars.items.len) {
            return error.IndexOutOfBounds;
        }
        return &self.bars.items[index];
    }

    /// Render all active progress bars.
    /// Handles terminal cursor repositioning and dynamic reflowing if bars finish.
    pub fn render(self: *MultiBar) !void {
        self.mutex.lockUncancelable(self.writer.io);
        defer self.mutex.unlock(self.writer.io);

        if (self.active_line == 0) return;

        try ansi_term.cursorUp(&self.writer.interface, self.active_line);

        var newly_active: usize = 0;

        for (self.bars.items) |*pb| {
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
            try self.writer.interface.flush();
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
