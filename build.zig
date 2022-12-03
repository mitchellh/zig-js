const std = @import("std");
const builtin = @import("builtin");

pub const pkg = std.build.Pkg{
    .name = "zig-js",
    .source = .{ .path = thisDir() ++ "/src/main.zig" },
};

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

pub const Options = struct {};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const tests = b.addTestExe("js-test", "src/main.zig");
    tests.setBuildMode(mode);
    tests.setTarget(target);
    tests.install();

    const test_step = b.step("test", "Run tests");
    const tests_run = tests.run();
    test_step.dependOn(&tests_run.step);

    // Example
    {
        const wasm = b.addSharedLibrary(
            "example",
            "example/main.zig",
            .{ .unversioned = {} },
        );
        wasm.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
        wasm.setBuildMode(mode);
        wasm.setOutputDir("example");
        wasm.addPackage(pkg);

        const step = b.step("example", "Build the example project (Zig only)");
        step.dependOn(&wasm.step);
    }
}
