const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Basic tests
test "basic matching" {
    try testing.expect(zglob.globMatch("abc", "abc"));
    try testing.expect(zglob.globMatch("*", "abc"));
    try testing.expect(zglob.globMatch("*", ""));
    try testing.expect(zglob.globMatch("**", ""));
    try testing.expect(zglob.globMatch("*c", "abc"));
    try testing.expect(!zglob.globMatch("*b", "abc"));
    try testing.expect(zglob.globMatch("a*", "abc"));
    try testing.expect(!zglob.globMatch("b*", "abc"));
    try testing.expect(zglob.globMatch("a*", "a"));
    try testing.expect(zglob.globMatch("*a", "a"));
    try testing.expect(zglob.globMatch("a*b*c*d*e*", "axbxcxdxe"));
    try testing.expect(zglob.globMatch("a*b*c*d*e*", "axbxcxdxexxx"));
    try testing.expect(zglob.globMatch("a*b?c*x", "abxbbxdbxebxczzx"));
    try testing.expect(!zglob.globMatch("a*b?c*x", "abxbbxdbxebxczzy"));
}

test "path matching" {
    try testing.expect(zglob.globMatch("a/*/test", "a/foo/test"));
    try testing.expect(!zglob.globMatch("a/*/test", "a/foo/bar/test"));
    try testing.expect(zglob.globMatch("a/**/test", "a/foo/test"));
    try testing.expect(zglob.globMatch("a/**/test", "a/foo/bar/test"));
    try testing.expect(zglob.globMatch("a/**/b/c", "a/foo/bar/b/c"));
    try testing.expect(zglob.globMatch("a\\*b", "a*b"));
    try testing.expect(!zglob.globMatch("a\\*b", "axb"));
}

test "character classes" {
    try testing.expect(zglob.globMatch("[abc]", "a"));
    try testing.expect(zglob.globMatch("[abc]", "b"));
    try testing.expect(zglob.globMatch("[abc]", "c"));
    try testing.expect(!zglob.globMatch("[abc]", "d"));
    try testing.expect(zglob.globMatch("x[abc]x", "xax"));
    try testing.expect(zglob.globMatch("x[abc]x", "xbx"));
    try testing.expect(zglob.globMatch("x[abc]x", "xcx"));
    try testing.expect(!zglob.globMatch("x[abc]x", "xdx"));
    try testing.expect(!zglob.globMatch("x[abc]x", "xay"));
    try testing.expect(zglob.globMatch("[?]", "?"));
    try testing.expect(!zglob.globMatch("[?]", "a"));
    try testing.expect(zglob.globMatch("[*]", "*"));
    try testing.expect(!zglob.globMatch("[*]", "a"));
}

test "character ranges" {
    try testing.expect(zglob.globMatch("[a-cx]", "a"));
    try testing.expect(zglob.globMatch("[a-cx]", "b"));
    try testing.expect(zglob.globMatch("[a-cx]", "c"));
    try testing.expect(!zglob.globMatch("[a-cx]", "d"));
    try testing.expect(zglob.globMatch("[a-cx]", "x"));
}

test "negated character classes" {
    try testing.expect(!zglob.globMatch("[^abc]", "a"));
    try testing.expect(!zglob.globMatch("[^abc]", "b"));
    try testing.expect(!zglob.globMatch("[^abc]", "c"));
    try testing.expect(zglob.globMatch("[^abc]", "d"));
    try testing.expect(!zglob.globMatch("[!abc]", "a"));
    try testing.expect(!zglob.globMatch("[!abc]", "b"));
    try testing.expect(!zglob.globMatch("[!abc]", "c"));
    try testing.expect(zglob.globMatch("[!abc]", "d"));
    try testing.expect(zglob.globMatch("[\\!]", "!"));
}

test "combined patterns" {
    try testing.expect(zglob.globMatch("a*b*[cy]*d*e*", "axbxcxdxexxx"));
    try testing.expect(zglob.globMatch("a*b*[cy]*d*e*", "axbxyxdxexxx"));
    try testing.expect(zglob.globMatch("a*b*[cy]*d*e*", "axbxxxyxdxexxx"));
}

test "braces" {
    try testing.expect(zglob.globMatch("test.{jpg,png}", "test.jpg"));
    try testing.expect(zglob.globMatch("test.{jpg,png}", "test.png"));
    try testing.expect(zglob.globMatch("test.{j*g,p*g}", "test.jpg"));
    try testing.expect(zglob.globMatch("test.{j*g,p*g}", "test.jpxxxg"));
    try testing.expect(zglob.globMatch("test.{j*g,p*g}", "test.jxg"));
    try testing.expect(!zglob.globMatch("test.{j*g,p*g}", "test.jnt"));
    try testing.expect(zglob.globMatch("test.{j*g,j*c}", "test.jnc"));
    try testing.expect(zglob.globMatch("test.{jpg,p*g}", "test.png"));
    try testing.expect(zglob.globMatch("test.{jpg,p*g}", "test.pxg"));
    try testing.expect(!zglob.globMatch("test.{jpg,p*g}", "test.pnt"));
    try testing.expect(zglob.globMatch("test.{jpeg,png}", "test.jpeg"));
    try testing.expect(!zglob.globMatch("test.{jpeg,png}", "test.jpg"));
    try testing.expect(zglob.globMatch("test.{jpeg,png}", "test.png"));
    try testing.expect(zglob.globMatch("test.{jp\\,g,png}", "test.jp,g"));
    try testing.expect(!zglob.globMatch("test.{jp\\,g,png}", "test.jxg"));
}

test "path with braces" {
    try testing.expect(zglob.globMatch("test/{foo,bar}/baz", "test/foo/baz"));
    try testing.expect(zglob.globMatch("test/{foo,bar}/baz", "test/bar/baz"));
    try testing.expect(!zglob.globMatch("test/{foo,bar}/baz", "test/baz/baz"));
    try testing.expect(zglob.globMatch("test/{foo*,bar*}/baz", "test/foooooo/baz"));
    try testing.expect(zglob.globMatch("test/{foo*,bar*}/baz", "test/barrrrr/baz"));
    try testing.expect(zglob.globMatch("test/{*foo,*bar}/baz", "test/xxxxfoo/baz"));
    try testing.expect(zglob.globMatch("test/{*foo,*bar}/baz", "test/xxxxbar/baz"));
    try testing.expect(zglob.globMatch("test/{foo/**,bar}/baz", "test/bar/baz"));
    try testing.expect(!zglob.globMatch("test/{foo/**,bar}/baz", "test/bar/test/baz"));
}

test "complex patterns" {
    try testing.expect(!zglob.globMatch("*.txt", "some/big/path/to/the/needle.txt"));
    try testing.expect(zglob.globMatch("some/**/needle.{js,tsx,mdx,ts,jsx,txt}", "some/a/bigger/path/to/the/crazy/needle.txt"));
    try testing.expect(zglob.globMatch("some/**/{a,b,c}/**/needle.txt", "some/foo/a/bigger/path/to/the/crazy/needle.txt"));
    try testing.expect(!zglob.globMatch("some/**/{a,b,c}/**/needle.txt", "some/foo/d/bigger/path/to/the/crazy/needle.txt"));
    try testing.expect(zglob.globMatch("a/{a{a,b},b}", "a/aa"));
    try testing.expect(zglob.globMatch("a/{a{a,b},b}", "a/ab"));
    try testing.expect(!zglob.globMatch("a/{a{a,b},b}", "a/ac"));
    try testing.expect(zglob.globMatch("a/{a{a,b},b}", "a/b"));
    try testing.expect(!zglob.globMatch("a/{a{a,b},b}", "a/c"));
    try testing.expect(zglob.globMatch("a/{b,c[}]*}", "a/b"));
    try testing.expect(zglob.globMatch("a/{b,c[}]*}", "a/c}xx"));
}

// Bash tests ported from micromatch
test "bash basic" {
    try testing.expect(!zglob.globMatch("a*", "*"));
    try testing.expect(!zglob.globMatch("a*", "**"));
    try testing.expect(!zglob.globMatch("a*", "\\*"));
    try testing.expect(!zglob.globMatch("a*", "a/*"));
    try testing.expect(!zglob.globMatch("a*", "b"));
    try testing.expect(!zglob.globMatch("a*", "bc"));
    try testing.expect(!zglob.globMatch("a*", "bcd"));
    try testing.expect(!zglob.globMatch("a*", "bdir/"));
    try testing.expect(!zglob.globMatch("a*", "Beware"));
    try testing.expect(zglob.globMatch("a*", "a"));
    try testing.expect(zglob.globMatch("a*", "ab"));
    try testing.expect(zglob.globMatch("a*", "abc"));
}

test "bash escaped" {
    try testing.expect(!zglob.globMatch("\\a*", "*"));
    try testing.expect(!zglob.globMatch("\\a*", "**"));
    try testing.expect(!zglob.globMatch("\\a*", "\\*"));
    try testing.expect(zglob.globMatch("\\a*", "a"));
    try testing.expect(!zglob.globMatch("\\a*", "a/*"));
    try testing.expect(zglob.globMatch("\\a*", "abc"));
    try testing.expect(zglob.globMatch("\\a*", "abd"));
    try testing.expect(zglob.globMatch("\\a*", "abe"));
    try testing.expect(!zglob.globMatch("\\a*", "b"));
    try testing.expect(!zglob.globMatch("\\a*", "bb"));
    try testing.expect(!zglob.globMatch("\\a*", "bcd"));
    try testing.expect(!zglob.globMatch("\\a*", "bdir/"));
    try testing.expect(!zglob.globMatch("\\a*", "Beware"));
    try testing.expect(!zglob.globMatch("\\a*", "c"));
    try testing.expect(!zglob.globMatch("\\a*", "ca"));
    try testing.expect(!zglob.globMatch("\\a*", "cb"));
    try testing.expect(!zglob.globMatch("\\a*", "d"));
    try testing.expect(!zglob.globMatch("\\a*", "dd"));
    try testing.expect(!zglob.globMatch("\\a*", "de"));
}

test "bash directories" {
    try testing.expect(!zglob.globMatch("b*/", "*"));
    try testing.expect(!zglob.globMatch("b*/", "**"));
    try testing.expect(!zglob.globMatch("b*/", "\\*"));
    try testing.expect(!zglob.globMatch("b*/", "a"));
    try testing.expect(!zglob.globMatch("b*/", "a/*"));
    try testing.expect(!zglob.globMatch("b*/", "abc"));
    try testing.expect(!zglob.globMatch("b*/", "abd"));
    try testing.expect(!zglob.globMatch("b*/", "abe"));
    try testing.expect(!zglob.globMatch("b*/", "b"));
    try testing.expect(!zglob.globMatch("b*/", "bb"));
    try testing.expect(!zglob.globMatch("b*/", "bcd"));
    try testing.expect(zglob.globMatch("b*/", "bdir/"));
    try testing.expect(!zglob.globMatch("b*/", "Beware"));
    try testing.expect(!zglob.globMatch("b*/", "c"));
    try testing.expect(!zglob.globMatch("b*/", "ca"));
    try testing.expect(!zglob.globMatch("b*/", "cb"));
    try testing.expect(!zglob.globMatch("b*/", "d"));
    try testing.expect(!zglob.globMatch("b*/", "dd"));
    try testing.expect(!zglob.globMatch("b*/", "de"));
}

// Test with captures
test "captures basic" {
    var captures = zglob.globMatchWithCaptures("a*c", "abc", testing.allocator) orelse {
        try testing.expect(false); // This should not happen
        return;
    };
    defer captures.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 1), captures.items.len);
    try testing.expectEqual(@as(usize, 1), captures.items[0].start);
    try testing.expectEqual(@as(usize, 2), captures.items[0].end);
}
