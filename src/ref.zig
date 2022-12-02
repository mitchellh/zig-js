const std = @import("std");
const assert = std.debug.assert;
const js = @import("main.zig");

/// Ref uniquely identifies a JS value. A JS value can't be physically
/// copied to the WASM environment so we represent it using a 64-bit number
/// into a table that is maintained on the JS side.
///
/// For a JS number (float64), the ref is literally the float64 (bitcasted).
/// For other types, we utilize the unused bits of the IEEE 754 NaN
/// representation to encode additional data into the ref. Bits 0-47
/// are used as an ID and bits 48-51 are used as a type ID.
pub const Ref = packed struct(u64) {
    head: u13 = nanMask,
    type_id: TypeId = .inferred,
    id: u48 = 0,

    /// Predefined refs.
    pub const nan: Ref = .{ .id = 0 };
    pub const @"null": Ref = .{ .id = 1 };
    pub const @"true": Ref = .{ .id = 2 };
    pub const @"false": Ref = .{ .id = 3 };
    pub const global: Ref = .{ .id = 4 };

    /// NaN in IEEE-754 is 0b0111_1111_1111_<anything other than all zeroes>.
    /// We always force NaN to have a 1-bit set in the 4th byte from the MSB
    /// so that we can use the lower 51 bits.
    const nanMask: u13 = 0x7FF8 >> 3;

    /// These are the type_id types we support.
    const TypeId = enum(u3) {
        inferred = 0,
        object = 1,
        string = 2,
        symbol = 3,
        function = 4,
    };

    /// Returns the type of a ref.
    pub fn typeOf(self: Ref) js.Type {
        // If we aren't a NaN then we have to be a number
        if (self.head != nanMask) return .number;

        return switch (self.type_id) {
            .object => .object,
            .string => .string,
            .symbol => .symbol,
            .function => .function,
            .inferred => switch (self.id) {
                0 => .number,
                1 => .null,
                2, 3 => .boolean,
                4 => .object,
                else => unreachable,
            },
        };
    }

    /// Returns true if the ref should be released.
    ///
    /// We don't need to release raw numbers because they're copied directly
    /// into our environment. And we don't need to release the predefined
    /// values because they're always retained.
    pub fn isReleasable(self: Ref) bool {
        return self.head != nanMask or
            self.type_id == .inferred;
    }

    pub fn toF64(self: Ref) f64 {
        assert(self.typeOf() == .number);
        return @bitCast(f64, self);
    }

    test "types" {
        const testing = std.testing;

        {
            const ref: Ref = .{ .type_id = .object };
            try testing.expectEqual(js.Type.object, ref.typeOf());
        }
    }

    test "floats" {
        const testing = std.testing;

        {
            const ref = @bitCast(Ref, @bitCast(u64, @as(f64, 1.234)));
            try testing.expectEqual(js.Type.number, ref.typeOf());
            try testing.expectEqual(@as(f64, 1.234), ref.toF64());
        }

        // zero
        {
            const ref = @bitCast(Ref, @bitCast(u64, @as(f64, 0)));
            try testing.expectEqual(js.Type.number, ref.typeOf());
            try testing.expectEqual(@as(f64, 0), ref.toF64());
        }
    }

    test "nans" {
        const testing = std.testing;

        // Stdlib nan
        {
            const ref = @bitCast(Ref, @bitCast(u64, std.math.nan_f64));
            try testing.expectEqual(js.Type.number, ref.typeOf());
            try testing.expect(std.math.isNan(ref.toF64()));
        }

        // Manual nan
        {
            const ref = @bitCast(Ref, @as(u64, 0x7FF8_0000_0000_0000));
            try testing.expectEqual(js.Type.number, ref.typeOf());
        }
    }
};

test {
    _ = Ref;
}
