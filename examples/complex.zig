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
        .write_newline_on_finish = false,
    });
    defer pb.clear() catch {};

    while (!pb.isFinished()) {
        try pb.add(1);
        try pb.render();

        std.time.sleep(std.time.ns_per_ms * 150);
    }
}
