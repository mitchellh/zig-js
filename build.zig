const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zig-js", .{ .source_file = .{ .path = "src/main.zig" } });

    const test_exe = b.addTest(.{
        .name = "js-test",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(test_exe);

    const test_step = b.step("test", "Run tests");
    const tests_run = b.addRunArtifact(test_exe);
    test_step.dependOn(&tests_run.step);

    // Example
    {
        const wasm = b.addSharedLibrary(.{
            .name = "example",
            .root_source_file = .{ .path = "example/main.zig" },
            .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
            .optimize = optimize,
        });
        wasm.addModule("zig-js", b.modules.get("zig-js").?);

        const step = b.step("example", "Build the example project (Zig only)");
        step.dependOn(&wasm.step);
    }
}
