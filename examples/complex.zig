const std = @import("std");
const ProgressBar = @import("progress");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var pb = ProgressBar.init(28, stdout.any(), .{
        .bar_prefix = '[',
        .bar_suffix = ']',
        .bar_fill_char = '=',
        .description = "A complex progress bar",
        .show_iterations = true,
        .show_percentage = true,
    });

    while (!pb.finished()) {
        try pb.add(1);
        std.time.sleep(std.time.ns_per_ms * 150);
    }
}
