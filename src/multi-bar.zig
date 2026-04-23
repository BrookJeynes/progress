const std = @import("std");
const bar = @import("bar.zig");
const ansi_term = @import("ansi-term.zig");
const Bar = bar.Bar;
const Config = bar.Config;

///A dynamic manager for handling multiple concurrent progress bars.
///Allocates memory on the heap and can grow dynamically.
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

    ///Add a new progress bar to the manager and allocate space for it.
    ///Overrides `write_newline_on_finish` to ensure terminal visual integrity.
    ///Returns the total number of bars currently managed.
    pub fn addBar(self: *MultiBar, max_progress: usize, config: Config) !usize {
        var safe_config = config;
        safe_config.write_newline_on_finish = false;

        const new_pb = try self.allocator.create(Bar);
        new_pb.* = Bar.init(max_progress, self.writer, safe_config);
        try self.bars.append(self.allocator, new_pb);
        try self.writer.interface.writeAll("\n");
        self.active_line += 1;
        return self.bars.items.len;
    }

    ///Returns a pointer to the bar at the given index.
    ///Not thread safe. The caller is responsible for synchronization
    ///if the bar is accessed concurrently with `render()` or other threads.
    pub fn bar(self: *MultiBar, index: usize) !*Bar {
        if (index >= self.bars.items.len)
            return error.IndexOutOfBounds;
        return self.bars.items[index];
    }

    ///Render all active progress bars.
    ///Handles terminal cursor repositioning and dynamic reflowing if bars finish.
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

///A static manager for handling multiple concurrent progress bars.
///Requires zero allocation, lives on the stack, and has a fixed maximum capacity.
pub fn MultiBarStatic(comptime max_bars: usize) type {
    return struct {
        const Self = @This();

        bars: [max_bars]Bar,
        len: usize,
        writer: *std.Io.File.Writer,
        mutex: std.Io.Mutex,
        active_lines: usize = 0,

        pub fn init(writer: *std.Io.File.Writer) Self {
            return .{
                .bars = undefined,
                .len = 0,
                .writer = writer,
                .mutex = std.Io.Mutex.init,
                .active_lines = 0,
            };
        }

        ///Add a new progress bar to the manager.
        ///Returns `error.TooMAnyBars` if the fixed capacity (`max_bars`) is reached.
        ///Overrides `write_newline_on_finish` to ensure terminal visual integrity.
        ///Returns the total number of bars currently managed.
        pub fn addBar(self: *Self, max_progress: usize, config: Config) !usize {
            if (self.len >= max_bars) return error.TooMAnyBars;

            var safe_config = config;
            safe_config.write_newline_on_finish = false;

            self.bars[self.len] = Bar.init(max_progress, self.writer, safe_config);
            self.len += 1;

            try self.writer.interface.writeAll("\n");
            self.active_lines += 1;

            return self.len;
        }

        ///Returns a pointer to the bar at the given index.
        ///Not thread safe. The caller is responsible for synchronization
        ///if the bar is accessed concurrently with `render()` or other threads.
        pub fn bar(self: *Self, index: usize) !*Bar {
            if (index >= self.len)
                return error.IndexOutOfBounds;
            return &self.bars[index];
        }

        ///Render all active progress bars.
        ///Handles terminal cursor repositioning and dynamic reflowing if bars finish.
        pub fn render(self: *Self) !void {
            self.mutex.lockUncancelable(self.writer.io);
            defer self.mutex.unlock(self.writer.io);

            if (self.active_lines == 0) return;

            try ansi_term.cursorUp(&self.writer.interface, self.active_lines);

            var newly_active: usize = 0;

            for (self.bars[0..self.len]) |*pb| {
                if (pb.isFinished() and pb.config.clear_on_finish) {
                    continue;
                }

                try ansi_term.clearCurrentLine(&self.writer.interface);
                try pb.render();

                try ansi_term.cursorDown(&self.writer.interface, 1);
                try ansi_term.setCursorColumn(&self.writer.interface, 0);

                newly_active += 1;
            }

            if (newly_active < self.active_lines) {
                const diff = self.active_lines - newly_active;
                for (0..diff) |_| {
                    try ansi_term.clearCurrentLine(&self.writer.interface);
                    try ansi_term.cursorDown(&self.writer.interface, 1);
                }
                try ansi_term.cursorUp(&self.writer.interface, diff);
            }

            self.active_lines = newly_active;
        }

        ///Restore the terminal cursor.
        ///No memory is freed as this manager is strictly stack-allocated.
        pub fn deinit(self: *Self) void {
            ansi_term.showCursor(&self.writer.interface) catch {};
            self.writer.interface.flush() catch {};
        }
    };
}
