const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Test the Fs struct functionality
test "Fs struct API" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // 0.17 threads an explicit I/O instance through every filesystem call.
    var io_state = std.Io.Threaded.init(allocator, .{});
    defer io_state.deinit();
    const io = io_state.io();

    // Initialize the Fs struct with an I/O instance and an allocator
    const fs = zglob.Fs.init(io, allocator);

    // Test getCwd
    const cwd = try fs.getCwd();
    defer allocator.free(cwd);
    try testing.expect(cwd.len > 0);

    // Test fileExists
    // This test should pass as the test file itself should exist
    const self_exists = fs.fileExists("tests/fs_struct_tests.zig");
    try testing.expect(self_exists);

    // Test isDirectory
    const tests_is_dir = fs.isDirectory("tests");
    try testing.expect(tests_is_dir);

    // Test non-existent directory
    const non_existent_dir = fs.isDirectory("this_directory_does_not_exist");
    try testing.expect(!non_existent_dir);

    // Test path operations
    const clean_path = try fs.cleanPath("tests/../tests/./fs_struct_tests.zig");
    defer allocator.free(clean_path);
    try testing.expect(std.mem.endsWith(u8, clean_path, "tests/fs_struct_tests.zig"));

    // Test path normalization
    const options = zglob.fs.PathResolutionOptions{};
    const norm_path = try fs.normalizePath("tests", "./fs_struct_tests.zig", options);
    defer allocator.free(norm_path);
    try testing.expect(std.mem.endsWith(u8, norm_path, "tests/fs_struct_tests.zig"));
}
