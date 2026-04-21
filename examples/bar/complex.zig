const std = @import("std");
const ProgressBar = @import("progress").Bar;

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);

    var pb1 = ProgressBar.init(28, &stdout_writer, .{
        .bar_prefix = '[',
        .bar_suffix = ']',
        .bar_fill_char = '=',
        .description = "Bar 1",
        .show_iterations = true,
        .show_percentage = true,
        .width = 60,
    });
    pb1.setColour(.Blue);

    var pb2 = ProgressBar.init(15, &stdout_writer, .{
        .bar_prefix = '|',
        .bar_suffix = '|',
        .bar_fill_char = '━',
        .description = "Bar 2",
        .show_iterations = true,
        .show_percentage = true,
        .width = 100,
        .show_background = true,
    });
    pb2.setColour(.{ .RGB = .{ .r = 255, .g = 0, .b = 127 } });
    pb2.setBgColour(.{ .RGB = .{ .r = 120, .g = 0, .b = 127 } });

    const progress_bars: [2]*ProgressBar = .{ &pb1, &pb2 };

    for (progress_bars, 0..) |pb, i| {
        while (!pb.isFinished()) {
            pb.add(1);
            try pb.render();

            if (i == 0) {
                if (pb.current_progress == 14) pb.updateDescription("Bar 1: nearly there");
            }

            try std.Io.sleep(init.io, std.Io.Duration.fromMilliseconds(150), .awake);
        }
    }
}
