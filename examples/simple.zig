const std = @import("std");
const ProgressBar = @import("progress");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var pb = ProgressBar.init(10, stdout.any(), .{});

    while (!pb.finished()) {
        try pb.add(1);
        std.time.sleep(std.time.ns_per_ms * 150);
    }
}
