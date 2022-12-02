//! A value represents a JS value.
const Value = @This();

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const js = @import("main.zig");

/// The ref to the value maintained on the JS side.
ref: js.Ref,

// This is the API that needs to be provided by the host environment.
extern "zig-js" fn valueGet(ref: u64, n: usize, len: usize) u64;
extern "zig-js" fn valueStringLen(ref: u64) u64;
extern "zig-js" fn valueStringCopy(ref: u64, addr: *u8, max: u64) void;
extern "zig-js" fn valueDeinit(ref: u64) void;

/// Deinitializes the value, allowing the JS environment to GC the value.
pub fn deinit(self: Value) void {
    // We avoid releasing values that aren't releasable. This avoids
    // crossing the js/wasm boundary for a bit of performance.
    if (self.ref.isReleasable()) valueDeinit(self.ref);
}

/// Get the value of a property of an object.
pub fn get(self: Value, n: []const u8) !Value {
    if (self.typeOf() != .object) return js.Error.InvalidType;
    return Value{ .ref = valueGet(self.ref, n.ptr, n.len) };
}

/// Returns the UTF-8 encoded string value. The resulting value must be
/// freed by the caller.
pub fn string(self: Value, alloc: Allocator) ![]const u8 {
    if (self.typeOf() != .string) return js.Error.InvalidType;

    // Get the length and allocate our pointer
    const len = valueStringLen(self.ref);
    var buf = try alloc.alloc(u8, len);
    errdefer alloc.free(buf);

    // Copy the string into the buffer
    valueStringCopy(self.ref, buf.ptr, buf.len);

    return buf;
}

/// Returns the type of this value.
pub fn typeOf(self: Value) js.Type {
    return self.ref.typeOf();
}
