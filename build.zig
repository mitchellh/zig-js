const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tests = b.addTest(.{
        .name = "js-test",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tests);

    const test_step = b.step("test", "Run tests");
    const tests_run = b.addRunArtifact(tests);
    test_step.dependOn(&tests_run.step);

    const zigjs = b.addModule("zig-js", .{
        .source_file = .{ .path = "src/main.zig" },
    });
    // Example
    {
        const wasm = b.addSharedLibrary(.{
            .name = "example",
            .root_source_file = .{ .path = "example/main.zig" },
            .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
            .optimize = optimize,
        });
        wasm.rdynamic = true;
        wasm.addModule("zig-js", zigjs);

        const step = b.step("example", "Build the example project (Zig only)");
        step.dependOn(&b.addInstallArtifact(wasm, .{
            .dest_dir = .{.override=.{.custom="../example"}},
        }).step);
    }
}
