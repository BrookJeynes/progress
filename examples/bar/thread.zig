const std = @import("std");
const ProgressBar = @import("progress").Bar;

pub fn threadWorker(bar: *ProgressBar, seed: usize) !void {
    var rand_impl = std.Random.DefaultPrng.init(seed);
    const num = @mod(rand_impl.random().int(i64), 1000);

    for (0..5) |_| {
        bar.add(1);
        try bar.render();

        try std.Io.sleep(bar.writer.io, std.Io.Duration.fromMilliseconds(num), .awake);
    }
}

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    var pb = ProgressBar.init(100, &stdout_writer, .{
        .description = "Progress bar with threads",
        .show_iterations = true,
        .show_percentage = true,
    });

    const thread_count = 20;
    var threads: [thread_count]std.Thread = undefined;
    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, threadWorker, .{ &pb, i });
    }

    for (threads) |thread| {
        thread.join();
    }
}
