const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Helper function to check for path components with OS-agnostic separators
fn hasPathComponent(path: []const u8, component: []const u8) bool {
    // Try with forward slashes
    if (std.mem.indexOf(u8, path, component) != null) {
        return true;
    }

    // Create a version with backslashes and try again
    var backslash_component: [100]u8 = undefined;
    var len: usize = 0;
    for (component) |c| {
        backslash_component[len] = if (c == '/') '\\' else c;
        len += 1;
    }
    return std.mem.indexOf(u8, path, backslash_component[0..len]) != null;
}

// Test the glob finder functionality using the traditional API
test "glob find files - traditional API" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // 0.17 threads an explicit I/O instance through every filesystem call.
    var io_state = std.Io.Threaded.init(allocator, .{});
    defer io_state.deinit();
    const io = io_state.io();

    // Get the current working directory using zglob.fs
    const fs_helper = zglob.fs.Fs.init(io, allocator);
    const cwd = try fs_helper.getCwd();
    defer allocator.free(cwd);

    // Create paths for the directories we'll use
    const tests_dir = try std.fmt.allocPrint(allocator, "{s}/tests", .{cwd});
    defer allocator.free(tests_dir);

    // Test finding files in the tests directory
    const matches = try zglob.globWithCwd(io, allocator, "*.zig", tests_dir);
    try testing.expect(matches.len > 0);

    // Verify we have found at least this test file
    var found_self = false;
    for (matches) |match_path| {
        if (std.mem.endsWith(u8, match_path, "glob_finder_tests.zig")) {
            found_self = true;
            break;
        }
    }
    try testing.expect(found_self);

    // Test with a more complex pattern
    const glob_tests = try zglob.globWithCwd(io, allocator, "*glob*test*.zig", tests_dir);
    try testing.expect(glob_tests.len > 0);

    // Test with pattern containing path separator
    const src_files = try zglob.globWithCwd(io, allocator, "src/*.zig", cwd);
    try testing.expect(src_files.len > 0);

    // Test with ** pattern
    const all_zig_files = try zglob.globWithCwd(io, allocator, "**/*.zig", cwd);
    try testing.expect(all_zig_files.len > src_files.len); // Should find more than just src files

    // Test with pattern starting with directory and including ** pattern
    const src_recursive_files = try zglob.globWithCwd(io, allocator, "src/**/*.zig", cwd);
    try testing.expect(src_recursive_files.len > 0);

    // Verify we find files in the src/fs/ subdirectory
    var found_fs_file = false;
    for (src_recursive_files) |match_path| {
        if (hasPathComponent(match_path, "src/fs/")) {
            found_fs_file = true;
            break;
        }
    }
    try testing.expect(found_fs_file);
}

// Test the glob finder functionality using the struct API
test "glob find files - struct API" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // 0.17 threads an explicit I/O instance through every filesystem call.
    var io_state = std.Io.Threaded.init(allocator, .{});
    defer io_state.deinit();
    const io = io_state.io();

    // Initialize zGlob with the allocator
    const glob_finder = zglob.zGlob.init(io, allocator);

    // Get the current working directory using glob_finder.fs
    const cwd = try glob_finder.fs.getCwd();
    defer allocator.free(cwd);

    // Create paths for the directories we'll use
    const tests_dir = try std.fmt.allocPrint(allocator, "{s}/tests", .{cwd});
    defer allocator.free(tests_dir);

    // Test finding files in the tests directory
    const matches = try glob_finder.globWithCwd("*.zig", tests_dir);
    try testing.expect(matches.len > 0);

    // Verify we have found at least this test file
    var found_self = false;
    for (matches) |match_path| {
        if (std.mem.endsWith(u8, match_path, "glob_finder_tests.zig")) {
            found_self = true;
            break;
        }
    }
    try testing.expect(found_self);

    // Test with a more complex pattern
    const glob_tests = try glob_finder.globWithCwd("*glob*test*.zig", tests_dir);
    try testing.expect(glob_tests.len > 0);

    // Test with pattern containing path separator
    const src_files = try glob_finder.globWithCwd("src/*.zig", cwd);
    try testing.expect(src_files.len > 0);

    // Test with ** pattern
    const all_zig_files = try glob_finder.globWithCwd("**/*.zig", cwd);
    try testing.expect(all_zig_files.len > src_files.len); // Should find more than just src files

    // Test with pattern starting with directory and including ** pattern
    const src_recursive_files = try glob_finder.globWithCwd("src/**/*.zig", cwd);
    try testing.expect(src_recursive_files.len > 0);

    // Verify we find files in the src/fs/ subdirectory
    var found_fs_file = false;
    for (src_recursive_files) |match_path| {
        if (hasPathComponent(match_path, "src/fs/")) {
            found_fs_file = true;
            break;
        }
    }
    try testing.expect(found_fs_file);
}
