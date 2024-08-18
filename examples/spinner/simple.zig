const std = @import("std");
const ProgressSpinner = @import("progress").Spinner;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var ps = ProgressSpinner.init(stdout.any(), .{
        .symbols = ProgressSpinner.PredefinedSymbols.default,
    });

    var iterations: usize = 0;
    while (!ps.isFinished()) {
        iterations += 1;
        try ps.render();

        if (iterations == 20) try ps.finish();

        std.time.sleep(std.time.ns_per_ms * 150);
    }
}
