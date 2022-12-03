const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const js = @import("main.zig");

/// Object is a JS object.
///
/// This is a higher-level of abstraction over js.Value and is the recommended
/// interface unless you have a specific reason to use the lower-levels. This
/// will provide a more ergonomic experience interacting with JS.
///
/// Note this uses a lot of comptime so this will bloat your WASM code size
/// since the Zig compiler will generate a separate implementation for
/// all the comptime permutations.
pub const Object = struct {
    value: js.Value,

    pub fn deinit(self: Object) void {
        self.value.deinit();
    }

    /// Get a property value of type T. This can only be used for types
    /// that don't require allocation. The compiler will tell you if you use
    /// the wrong type.
    ///
    /// See getAlloc for more details.
    pub fn get(self: Object, comptime T: type, n: []const u8) !Get(T).result {
        const info = Get(T);
        if (info.allocs) @compileError("use getAlloc for types that require allocations");
        return self.getAlloc(T, undefined, n);
    }

    /// Get a property value of type T. type T may or may not require allocation.
    /// If it requires allocation, you must free the result.
    ///
    /// If the type T is optional, then null or undefined JS values will
    /// return "null". If T is not optional, null or undefined will return
    /// an error.
    pub fn getAlloc(
        self: Object,
        comptime T: type,
        alloc: Allocator,
        n: []const u8,
    ) !Get(T).result {
        const v = try self.value.get(n);
        errdefer v.deinit();
        return convertValue(T, alloc, v);
    }

    /// Set a value of a property. The type of v must be able to turn
    /// into a value (see Value.init).
    pub fn set(self: Object, n: []const u8, v: anytype) !void {
        const T = @TypeOf(v);
        const js_value = js.Value.init(v);
        defer if (T != js.Value) js_value.deinit();
        try self.value.set(n, js_value);
    }

    /// Call a function on a object. This will set the "this" parameter
    /// to the object properly. This should only be used with return types
    /// that don't need any allocations.
    pub fn call(
        self: Object,
        comptime T: type,
        n: []const u8,
        args: anytype,
    ) !Get(T).result {
        const info = Get(T);
        if (info.allocs) @compileError("use callAlloc for types that require allocations");
        return self.callAlloc(T, undefined, n, args);
    }

    /// Call a function on an object where the return type requires allocation.
    pub fn callAlloc(
        self: Object,
        comptime T: type,
        alloc: Allocator,
        n: []const u8,
        args: anytype,
    ) !Get(T).result {
        // Build our arguments.
        const argsInfo = @typeInfo(@TypeOf(args)).Struct;
        assert(argsInfo.is_tuple);
        var js_args: [argsInfo.fields.len]js.Value = undefined;
        inline for (argsInfo.fields) |field, i| {
            js_args[i] = switch (field.field_type) {
                js.Object => @field(args, field.name),
                else => js.Value.init(@field(args, field.name)),
            };
        }

        // Invoke
        const f = try self.value.get(n);
        defer f.deinit();
        const v = try f.apply(self.value, &js_args);
        errdefer v.deinit();
        return try convertValue(T, alloc, v);
    }

    fn convertValue(comptime T: type, alloc: Allocator, v: js.Value) !Get(T).result {
        const info = Get(T);
        const optional = @typeInfo(T) == .Optional;

        // Get the value no matter what type it is.
        defer if (!info.retains) v.deinit();

        // If the return type is optional, then handle null/undefined
        const vt = v.typeOf();
        if (vt == .null or vt == .undefined) {
            if (optional) return null;
            return js.Error.InvalidType;
        }

        // Based on the return type we process the JS value
        switch (info.result) {
            js.Value => return v,

            Object => {
                if (vt != .object) return js.Error.InvalidType;
                return Object{ .value = v };
            },

            bool => return try v.boolean(),
            []u8 => return try v.string(alloc),
            f16, f32, f64 => return try v.float(),

            else => {},
        }

        return js.Error.InvalidType;
    }

    /// Information about our result type based on get calls.
    const GetInfo = struct {
        /// The result type for this get.
        result: type,

        /// True if the result type will allocate
        allocs: bool = false,

        /// True if we want to retain the js value.
        retains: bool = false,
    };

    /// Returns the result of a get call based on the type. This also
    /// creates a compile error if trying to get a type that we don't support.
    fn Get(comptime Raw: type) GetInfo {
        const T = t: {
            const info = @typeInfo(Raw);
            break :t if (info == .Optional) info.Optional.child else Raw;
        };

        return switch (T) {
            void => .{ .result = void },
            Object => .{ .result = Object, .retains = true },
            js.String => .{ .result = []u8, .allocs = true },
            js.Value => .{ .result = js.Value, .retains = true },
            bool, f16, f32, f64 => .{ .result = T },

            else => {
                @compileLog(T);
                @compileError("unsupported type");
            },
        };
    }
};
