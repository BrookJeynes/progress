const std = @import("std");
const ProgressSpinner = @import("progress").Spinner;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var ps = ProgressSpinner.init(stdout.any(), .{
        .description = "Task 1",
        .symbols = &[_]u21{ '⣾', '⣷', '⣯', '⣟', '⡿', '⢿', '⣻', '⣽' },
        .completion_character = '✓',
    });

    var iterations: usize = 0;
    while (!ps.isFinished()) {
        iterations += 1;
        try ps.render();

        if (iterations == 10) ps.updateDescription("Task 1.1");
        if (iterations == 13) ps.updateDescription("Task 1.2");
        if (iterations == 20) try ps.updateDescriptionNewline("Task 2.0");
        if (iterations == 23) try ps.updateDescriptionNewline("Task 3.0");
        if (iterations == 26) ps.updateDescription("Task 3.1");
        if (iterations == 30) try ps.updateDescriptionNewline("Task 4.0");
        if (iterations == 40) try ps.finish();

        std.time.sleep(std.time.ns_per_ms * 150);
    }
}
