const std = @import("std");
const ProgressBar = @import("progress").Bar;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var pb1 = ProgressBar.init(28, stdout.any(), .{
        .bar_prefix = '[',
        .bar_suffix = ']',
        .bar_fill_char = '=',
        .description = "A complex progress bar",
        .show_iterations = true,
        .show_percentage = true,
        .width = 60,
    });
    var pb2 = ProgressBar.init(15, stdout.any(), .{
        .bar_prefix = '|',
        .bar_suffix = '|',
        .bar_fill_char = '█',
        .description = "A second complex progress bar",
        .show_iterations = true,
        .show_percentage = true,
        .width = 100,
    });
    const progress_bars: [2]*ProgressBar = .{ &pb1, &pb2 };

    for (progress_bars, 0..) |pb, i| {
        while (!pb.isFinished()) {
            pb.add(1);
            try pb.render();

            if (i == 0) {
                if (pb.current_progress == 14) pb.updateDescription("Half way there");
            }

            std.time.sleep(std.time.ns_per_ms * 150);
        }
    }
}
