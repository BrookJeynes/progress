const std = @import("std");
const ProgressSpinner = @import("progress").Spinner;

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    var ps = ProgressSpinner.init(&stdout_writer, .{
        .symbols = ProgressSpinner.PredefinedSymbols.default,
    });

    var iterations: usize = 0;
    while (!ps.isFinished()) {
        iterations += 1;
        try ps.render();

        if (iterations == 20) try ps.finish();

        try std.Io.sleep(init.io, std.Io.Duration.fromMilliseconds(150), .awake);
    }
}
