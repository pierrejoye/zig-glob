const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Test the MatchGlob struct functionality
test "MatchGlob struct basic matching" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Initialize the MatchGlob struct with an allocator
    const matcher = zglob.MatchGlob.init(allocator);

    // Test basic pattern matching
    try testing.expect(matcher.match("abc", "abc"));
    try testing.expect(matcher.match("*", "abc"));
    try testing.expect(matcher.match("*", ""));
    try testing.expect(matcher.match("**", ""));
    try testing.expect(matcher.match("*c", "abc"));
    try testing.expect(!matcher.match("*b", "abc"));
    try testing.expect(matcher.match("a*", "abc"));
    try testing.expect(!matcher.match("b*", "abc"));
    try testing.expect(matcher.match("a*", "a"));
    try testing.expect(matcher.match("*a", "a"));
    try testing.expect(matcher.match("a*b*c*d*e*", "axbxcxdxe"));
    try testing.expect(matcher.match("a*b*c*d*e*", "axbxcxdxexxx"));
    try testing.expect(matcher.match("a*b?c*x", "abxbbxdbxebxczzx"));
    try testing.expect(!matcher.match("a*b?c*x", "abxbbxdbxebxczzy"));
}

// Test path matching with MatchGlob struct
test "MatchGlob struct path matching" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Initialize the MatchGlob struct with an allocator
    const matcher = zglob.MatchGlob.init(allocator);

    // Test path pattern matching
    try testing.expect(matcher.match("a/*/test", "a/foo/test"));
    try testing.expect(!matcher.match("a/*/test", "a/foo/bar/test"));
    try testing.expect(matcher.match("a/**/test", "a/foo/test"));
    try testing.expect(matcher.match("a/**/test", "a/foo/bar/test"));
    try testing.expect(matcher.match("a/**/b/c", "a/foo/bar/b/c"));
    try testing.expect(matcher.match("a\\*b", "a*b"));
    try testing.expect(!matcher.match("a\\*b", "axb"));
}

// Test captures with MatchGlob struct
test "MatchGlob struct captures" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Initialize the MatchGlob struct with an allocator
    const matcher = zglob.MatchGlob.init(allocator);

    // Test with captures
    if (matcher.matchWithCaptures("a*c", "abc")) |maybe_captures| {
        var captures = maybe_captures;
        defer captures.deinit(allocator);
        try testing.expectEqual(@as(usize, 1), captures.items.len);
        try testing.expectEqual(@as(usize, 1), captures.items[0].start);
        try testing.expectEqual(@as(usize, 2), captures.items[0].end);
    } else {
        try testing.expect(false); // Should have matched
    }

    // Test with multiple captures
    if (matcher.matchWithCaptures("a*b*c", "axxbyc")) |maybe_captures| {
        var captures = maybe_captures;
        defer captures.deinit(allocator);
        try testing.expectEqual(@as(usize, 2), captures.items.len);
        try testing.expectEqual(@as(usize, 1), captures.items[0].start);
        try testing.expectEqual(@as(usize, 3), captures.items[0].end);
        try testing.expectEqual(@as(usize, 4), captures.items[1].start);
        try testing.expectEqual(@as(usize, 5), captures.items[1].end);
    } else {
        try testing.expect(false); // Should have matched
    }

    // Test non-matching pattern (should return null)
    try testing.expect(matcher.matchWithCaptures("a*z", "abc") == null);
}
