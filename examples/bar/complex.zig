const std = @import("std");
const ProgressBar = @import("progress").Bar;

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
        .width = 60,
    });
    defer pb.clear() catch {};

    while (!pb.isFinished()) {
        pb.add(1);
        try pb.render();

        if (pb.current_progress == 14) pb.updateDescription("Half way there");

        std.time.sleep(std.time.ns_per_ms * 150);
    }
}
