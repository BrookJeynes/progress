const std = @import("std");

const name = "progress";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule(name, .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const progress = b.addLibrary(.{
        .name = name,
        .root_module = mod,
    });

    const docs = b.addInstallDirectory(.{
        .source_dir = progress.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs.step);

    for ([_][]const u8{ "simple", "complex", "thread" }) |example| {
        const run_step = b.step(b.fmt("run-bar-{s}", .{example}), b.fmt("Run bar/{s}.zig example", .{example}));
        const exe = b.addExecutable(.{
            .name = example,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("examples/bar/{s}.zig", .{example})),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport(name, mod);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&b.addInstallArtifact(exe, .{}).step);

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        run_step.dependOn(&run_cmd.step);
    }

    for ([_][]const u8{ "simple", "complex" }) |example| {
        const run_step = b.step(b.fmt("run-spinner-{s}", .{example}), b.fmt("Run spinner/{s}.zig example", .{example}));
        const exe = b.addExecutable(.{
            .name = example,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("examples/spinner/{s}.zig", .{example})),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport(name, mod);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&b.addInstallArtifact(exe, .{}).step);

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        run_step.dependOn(&run_cmd.step);
    }
}
