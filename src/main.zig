//! The "js" package provides an interface to the JavaScript host environment
//! from a WASM module. To function, this requires the JS glue code to be
//! available in the host environment and configured in the imports table
//! when instantiating the WASM module.
//!
//! Usage of this package causes the WASM/JS boundary to be crossed a LOT
//! and this is generally not very fast and not an optimal way to use wasm.
//! The optimal way to use WASM is more like a GPU: have the host (or wasm
//! module) preload a bunch of work into a byte buffer and send it over
//! in one single call. However, this approach is pretty painful.
//! This packge makes interfacing with JS very, very easy. Consider the
//! tradeoffs and choose what is best for you.
//!
//! This is based on the Go "syscall/js" library. It is rewritten from
//! scratch but copies some fundamental ideas such as the format of the
//! "ref" to identify a JS value. It differs greatly in other areas since
//! Zig doesn't have a runtime and doesn't behave anything like Go.

const ref = @import("ref.zig");
const value = @import("value.zig");
pub usingnamespace ref;
pub usingnamespace value;

/// Errors that can occur in this package.
pub const Error = error{
    /// The wrong type for the receiver.
    InvalidType,
};

/// The global object, i.e. "global" in the JS environment.
pub fn global() value.Value {
    return @intToEnum(value.Value, @bitCast(u64, ref.Ref.global));
}

test {
    @import("std").testing.refAllDecls(@This());
}
