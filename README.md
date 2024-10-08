# progress

A simple thread safe progress bar and spinner library.

![Recording](https://github.com/user-attachments/assets/227297c4-15a5-4c68-a8bc-49d7e1505a79)

## Adding to your program
1. Fetch the package.  
    `zig fetch --save git+https://github.com/BrookJeynes/progress`
2. Add to your `build.zig`.
    ```zig
    const progress = b.dependency("progress", .{}).module("progress");
    exe.root_module.addImport("progress", progress);
    ```

## Minimal example
```zig
const std = @import("std");
const ProgressBar = @import("progress").Bar;
const ProgressSpinner = @import("progress").Spinner;

pub fn bar() !void {
    const stdout = std.io.getStdOut().writer();
    var pb = ProgressBar.init(10, stdout.any(), .{});

    while (!pb.isFinished()) {
        pb.add(1);
        try pb.render();

        std.time.sleep(std.time.ns_per_ms * 150);
    }
}

pub fn spinner() !void {
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
```

You can find more examples in the `examples/` folder.  
For more information, see the source code or documentation (`zig build docs`).

## Contributing
Contributions, issues, and feature requests are always welcome! This project is 
using the latest stable release of Zig (0.13.0).
