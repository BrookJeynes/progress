const std = @import("std");
const ProgressBar = @import("progress").Bar;

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    var pb = ProgressBar.init(10, &stdout_writer, .{});

    while (!pb.isFinished()) {
        pb.add(1);
        try pb.render();

        try std.Io.sleep(init.io, std.Io.Duration.fromMilliseconds(150), .awake);
    }
}
