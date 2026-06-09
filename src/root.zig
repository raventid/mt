//! MT — minimalistic translator.
//!
//! This is the library root: the public declarations here are what other
//! packages get when they `@import("mt")`.
const std = @import("std");

/// Package version.
pub const version = "0.0.0";

/// Placeholder for translator functionality.
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "add" {
    try std.testing.expectEqual(@as(i32, 10), add(3, 7));
}
