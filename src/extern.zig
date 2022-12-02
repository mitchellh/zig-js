const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const js = @import("main.zig");

// This is the API that must be provided by the host environment. For
// testing we mock it out so that we can test a well-behaved system.
pub usingnamespace if (!builtin.is_test) struct {
    extern "zig-js" fn valueGet(id: u64, n: usize, len: usize) u64;
    extern "zig-js" fn valueStringCreate(addr: [*]const u8, len: u64) u64;
    extern "zig-js" fn valueStringLen(id: u64) u64;
    extern "zig-js" fn valueStringCopy(id: u64, addr: *u8, max: u64) void;
    extern "zig-js" fn valueDeinit(id: u64) void;
} else struct {
    const alloc = std.testing.allocator;

    /// This is what we store in our array list so that we can manage
    /// memory correctly even in tests.
    const StoredValue = union(enum) {
        string: []const u8,

        pub fn deinit(self: StoredValue) void {
            switch (self) {
                .string => |v| alloc.free(v),
            }
        }
    };

    /// Mimics the JS style values array except we never reuse IDs
    /// since we're testing and don't plan on overflowing 32-bits.
    var values: std.ArrayListUnmanaged(StoredValue) = .{};

    pub fn deinit() void {
        // Note: we don't deinit the value items here so we can test
        // that we deinit properly in our tests.

        values.deinit(alloc);
    }

    pub fn valueStringCreate(addr: [*]const u8, len: u64) u64 {
        // Copy the value
        const copy = alloc.dupe(u8, addr[0..len]) catch unreachable;

        // Write it
        values.append(alloc, .{ .string = copy }) catch unreachable;

        // Create the ref
        const ref: js.Ref = .{ .type_id = .string, .id = @intCast(u32, values.items.len - 1) };
        return @bitCast(u64, ref);
    }

    pub fn valueStringLen(id: u64) u64 {
        return values.items[id].string.len;
    }

    pub fn valueStringCopy(id: u64, addr: [*]u8, max: u64) void {
        std.mem.copy(u8, addr[0..max], values.items[id].string);
    }

    pub fn valueDeinit(id: u64) void {
        values.items[id].deinit();
    }
};
