const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const js = @import("main.zig");

// This is the API that needs to be provided by the host environment.
extern "zig-js" fn valueGet(id: u64, n: usize, len: usize) u64;
extern "zig-js" fn valueStringLen(id: u64) u64;
extern "zig-js" fn valueStringCopy(id: u64, addr: *u8, max: u64) void;
extern "zig-js" fn valueDeinit(id: u64) void;

/// A value represents a JS value. This is the low-level "untyped" interface
/// to any generic JS value. It is more ergonomic to use the higher level
/// wrappers such as Object.
pub const Value = enum(u64) {
    // Predefined values
    nan = @bitCast(u64, js.Ref.nan),
    null = @bitCast(u64, js.Ref.@"null"),
    true = @bitCast(u64, js.Ref.@"true"),
    false = @bitCast(u64, js.Ref.@"false"),
    global = @bitCast(u64, js.Ref.global),

    _,

    /// Deinitializes the value, allowing the JS environment to GC the value.
    pub fn deinit(self: Value) void {
        // We avoid releasing values that aren't releasable. This avoids
        // crossing the js/wasm boundary for a bit of performance.
        if (self.ref().isReleasable()) valueDeinit(self.ref().id);
    }

    /// Get the value of a property of an object.
    pub fn get(self: Value, n: []const u8) !Value {
        if (self.typeOf() != .object) return js.Error.InvalidType;
        return Value{ .ref = valueGet(self.ref().id, n.ptr, n.len) };
    }

    /// Returns the UTF-8 encoded string value. The resulting value must be
    /// freed by the caller.
    pub fn string(self: Value, alloc: Allocator) ![]const u8 {
        if (self.typeOf() != .string) return js.Error.InvalidType;

        // Get the length and allocate our pointer
        const len = valueStringLen(self.ref().id);
        var buf = try alloc.alloc(u8, len);
        errdefer alloc.free(buf);

        // Copy the string into the buffer
        valueStringCopy(self.ref().id, buf.ptr, buf.len);

        return buf;
    }

    /// Returns the type of this value.
    pub fn typeOf(self: Value) js.Type {
        return self.ref().typeOf();
    }

    inline fn ref(self: Value) js.Ref {
        return @bitCast(u64, @enumToInt(self));
    }
};
