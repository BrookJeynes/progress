const std = @import("std");
const ProgressBar = @import("progress").Bar;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var pb = ProgressBar.init(10, stdout.any(), .{});

    while (!pb.isFinished()) {
        pb.add(1);
        try pb.render();

        std.time.sleep(std.time.ns_per_ms * 150);
    }
}
