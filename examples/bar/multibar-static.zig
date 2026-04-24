const std = @import("std");
const progress = @import("progress");
const MultiBar = progress.MultiBar.MultiBar;

pub fn threadWorker(manager: *MultiBar, index: usize, seed: usize) !void {
    var rand_impl = std.Random.DefaultPrng.init(seed);
    const delay = @mod(rand_impl.random().int(i64), 100) + 20;

    const pb = try manager.bar(index);

    while (!pb.isFinished()) {
        pb.add(1);
        try manager.render();

        try std.Io.sleep(manager.writer.io, std.Io.Duration.fromMilliseconds(delay), .awake);
    }
}

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);

    const num_bars = 5;
    var buf: [MultiBar.bufSize(num_bars)]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);

    var manager = MultiBar.init(fba.allocator(), &stdout_writer);
    defer manager.deinit();

    for (0..num_bars) |i| {
        var desc_buf: [32]u8 = undefined;
        const desc = try std.fmt.bufPrint(&desc_buf, "Task {d}", .{i + 1});

        _ = try manager.addBar(100, .{
            .description = desc,
            .show_percentage = true,
            .write_newline_on_finish = false,
            .clear_on_finish = true,
        });
    }

    var threads: [num_bars]std.Thread = undefined;
    for (0..num_bars) |i| {
        threads[i] = try std.Thread.spawn(.{}, threadWorker, .{ &manager, i, i * 100 });
    }

    for (threads) |thread| {
        thread.join();
    }
}
