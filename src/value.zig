const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const js = @import("main.zig");

// This is the API that needs to be provided by the host environment.
extern "zig-js" fn valueGet(id: u64, n: usize, len: usize) u64;
extern "zig-js" fn valueStringCreate(addr: *u8, len: u64) u64;
extern "zig-js" fn valueStringLen(id: u64) u64;
extern "zig-js" fn valueStringCopy(id: u64, addr: *u8, max: u64) void;
extern "zig-js" fn valueDeinit(id: u64) void;

/// Only used with Value.init to denote a string type.
///
/// This is NOT a JS string. This is just a sentinel type so that we can
/// differentiate a slice and a "string" when trying to convert a Zig
/// value into a JS value.
pub const String = struct { ptr: [*]u8, len: usize };

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

    /// Converts a Zig value to a JS value.
    ///
    /// In order to tell the difference between a "string" and an array, strings
    /// must be wrapped in the String type prior to calling this. Otherwise,
    /// an array is assumed. If a string is created, the bytes pointed to by the
    /// string can be freed after this call -- they are copied to the JS side.
    pub fn init(x: anytype) Value {
        return switch (@typeInfo(@TypeOf(x))) {
            .Null => .null,
            .Bool => if (x) .true else .false,
            .ComptimeInt => init(@intToFloat(f64, x)),
            .ComptimeFloat => init(@floatCast(f64, x)),
            .Float => |t| float: {
                if (t.bits > 64) @compileError("Value only supports floats up to 64 bits");
                if (std.math.isNan(x)) break :float .nan;
                break :float @intToEnum(Value, @bitCast(u64, @floatCast(f64, x)));
            },

            // All numbers in JS are 64-bit floats, so we try the conversion
            // here and accept a runtime/compile-time error if x is invalid.
            .Int => init(@intToFloat(f64, x)),

            else => switch (@TypeOf(x)) {
                String => @intToEnum(Value, valueStringCreate(x.ptr, x.len)),
                else => unreachable,
            },
        };
    }

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

    /// Returns the float value if this is a number.
    pub fn float(self: Value) f64 {
        assert(self.typeOf() == .number);
        return @bitCast(f64, @enumToInt(self));
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
        return @bitCast(js.Ref, @enumToInt(self));
    }
};

test "Value.init: null" {
    const testing = std.testing;
    try testing.expectEqual(Value.null, Value.init(null));
}

test "Value.init: bools" {
    const testing = std.testing;
    try testing.expectEqual(Value.true, Value.init(true));
    try testing.expectEqual(Value.false, Value.init(false));
}

test "Value.init: floats" {
    const testing = std.testing;
    try testing.expectEqual(Value.nan, Value.init(std.math.nan_f16));
    try testing.expectEqual(Value.nan, Value.init(std.math.nan_f32));
    try testing.expectEqual(Value.nan, Value.init(std.math.nan_f64));

    {
        const v = Value.init(1.234);
        try testing.expectEqual(js.Type.number, v.typeOf());
        try testing.expectEqual(@as(f64, 1.234), v.float());
    }
}

test "Value.init: ints" {
    const testing = std.testing;

    {
        const v = Value.init(14);
        try testing.expectEqual(js.Type.number, v.typeOf());
        try testing.expectEqual(@as(f64, 14), v.float());
    }
}
