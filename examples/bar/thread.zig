const std = @import("std");
const ProgressBar = @import("progress").Bar;

pub fn threadWorker(bar: *ProgressBar, seed: usize) !void {
    var rand_impl = std.rand.DefaultPrng.init(seed);
    const num = @mod(rand_impl.random().int(u64), 1000);

    for (0..5) |_| {
        bar.add(1);
        try bar.render();

        std.time.sleep(std.time.ns_per_ms * num);
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var pb = ProgressBar.init(100, stdout.any(), .{
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
