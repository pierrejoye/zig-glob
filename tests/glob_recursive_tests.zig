const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const path = std.fs.path;

// Helper function to create test files
fn createTestDir(io: std.Io, allocator: Allocator) ![]const u8 {
    // Create a temporary test directory
    const fs_helper = zglob.Fs.init(io, std.heap.page_allocator);
    const cwd = try fs_helper.getCwd();
    defer std.heap.page_allocator.free(cwd);

    const test_dir = try path.join(allocator, &[_][]const u8{ cwd, "glob_recursive_test_dir" });

    // Clean up any existing test directory
    std.Io.Dir.cwd().deleteTree(io, test_dir) catch {};

    // Create test directories
    try std.Io.Dir.cwd().createDirPath(io, test_dir);

    const dirs = [_][]const u8{
        "dir1",
        "dir2",
        "dir3/subdir1",
        "dir3/subdir2",
        "test_dir",
    };

    for (dirs) |dir_path| {
        const full_dir_path = try path.join(allocator, &[_][]const u8{ test_dir, dir_path });
        defer allocator.free(full_dir_path);
        try std.Io.Dir.cwd().createDirPath(io, full_dir_path);
    }

    // Create some test files
    const files = [_][]const u8{
        "file1.txt",
        "test_file.txt",
        "test_file.js",
        "dir1/test_file.txt",
        "dir1/other.txt",
        "dir2/test_file.txt",
        "dir2/file.js",
        "dir3/subdir1/test_file.txt",
        "dir3/subdir1/file.md",
        "dir3/subdir2/test_file.txt",
        "test_dir/test_file.txt",
    };

    for (files) |file_path| {
        const full_path = try path.join(allocator, &[_][]const u8{ test_dir, file_path });
        defer allocator.free(full_path);

        // Create parent directories if needed
        const dir_name = path.dirname(full_path) orelse "";
        try std.Io.Dir.cwd().createDirPath(io, dir_name);

        const file = try std.Io.Dir.createFileAbsolute(io, full_path, .{});
        try file.writeStreamingAll(io, "test content");
        file.close(io);
    }

    return test_dir;
}

fn cleanupTestDir(io: std.Io, test_dir: []const u8) !void {
    try std.Io.Dir.cwd().deleteTree(io, test_dir);
}

test "glob recursive pattern with **" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 0.17 threads an explicit I/O instance through every filesystem call.
    var io_state = std.Io.Threaded.init(allocator, .{});
    defer io_state.deinit();
    const io = io_state.io();

    const test_dir = try createTestDir(io, allocator);
    defer cleanupTestDir(io, test_dir) catch {};

    // Test finding all test_file.txt recursively
    {
        const pattern = try path.join(allocator, &[_][]const u8{ test_dir, "**/test_file.txt" });
        const results = try zglob.glob(io, allocator, pattern);
        defer {
            for (results) |result| {
                allocator.free(result);
            }
            allocator.free(results);
        }

        // Should find all 5 test_file.txt files
        try testing.expectEqual(@as(usize, 5), results.len);

        // Verify we found all expected files
        var found_in_root = false;
        var found_in_dir1 = false;
        var found_in_dir2 = false;
        var found_in_dir3_subdir1 = false;
        var found_in_dir3_subdir2 = false;

        for (results) |result| {
            if (std.mem.indexOf(u8, result, path.sep_str ++ "test_file.txt") != null and
                std.mem.count(u8, result, path.sep_str) == std.mem.count(u8, test_dir, path.sep_str) + 1)
            {
                found_in_root = true;
            } else if (std.mem.indexOf(u8, result, path.sep_str ++ "dir1" ++ path.sep_str ++ "test_file.txt") != null) {
                found_in_dir1 = true;
            } else if (std.mem.indexOf(u8, result, path.sep_str ++ "dir2" ++ path.sep_str ++ "test_file.txt") != null) {
                found_in_dir2 = true;
            } else if (std.mem.indexOf(u8, result, path.sep_str ++ "dir3" ++ path.sep_str ++ "subdir1" ++ path.sep_str ++ "test_file.txt") != null) {
                found_in_dir3_subdir1 = true;
            } else if (std.mem.indexOf(u8, result, path.sep_str ++ "dir3" ++ path.sep_str ++ "subdir2" ++ path.sep_str ++ "test_file.txt") != null) {
                found_in_dir3_subdir2 = true;
            }
        }

        try testing.expect(found_in_root);
        try testing.expect(found_in_dir1);
        try testing.expect(found_in_dir2);
        try testing.expect(found_in_dir3_subdir1);
        try testing.expect(found_in_dir3_subdir2);
    }

    // Test finding all .txt files in dir1 and subdirectories
    {
        const pattern = try path.join(allocator, &[_][]const u8{ test_dir, "dir1", "**/*.txt" });
        const results = try zglob.glob(io, allocator, pattern);
        defer {
            for (results) |result| {
                allocator.free(result);
            }
            allocator.free(results);
        }

        try testing.expectEqual(@as(usize, 2), results.len);

        // Verify we found all expected files
        var found_test_file = false;
        var found_other = false;

        for (results) |result| {
            if (std.mem.indexOf(u8, result, path.sep_str ++ "dir1" ++ path.sep_str ++ "test_file.txt") != null) {
                found_test_file = true;
            } else if (std.mem.indexOf(u8, result, path.sep_str ++ "dir1" ++ path.sep_str ++ "other.txt") != null) {
                found_other = true;
            }
        }

        try testing.expect(found_test_file);
        try testing.expect(found_other);
    }

    // Test finding files by pattern across subdirectories
    {
        const pattern = try path.join(allocator, &[_][]const u8{ test_dir, "**/*test*.txt" });
        const results = try zglob.glob(io, allocator, pattern);
        defer {
            for (results) |result| {
                allocator.free(result);
            }
            allocator.free(results);
        }

        // Should find all 6 test*.txt files (including test_dir/test_file.txt)
        try testing.expectEqual(@as(usize, 6), results.len);
    }
}

test "glob with simple wildcard" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 0.17 threads an explicit I/O instance through every filesystem call.
    var io_state = std.Io.Threaded.init(allocator, .{});
    defer io_state.deinit();
    const io = io_state.io();

    const test_dir = try createTestDir(io, allocator);
    defer cleanupTestDir(io, test_dir) catch {};

    // Test finding all .txt files in the root test directory
    {
        const pattern = try path.join(allocator, &[_][]const u8{ test_dir, "*.txt" });
        const results = try zglob.glob(io, allocator, pattern);
        defer {
            for (results) |result| {
                allocator.free(result);
            }
            allocator.free(results);
        }

        // Should find 2 .txt files in the root
        try testing.expectEqual(@as(usize, 2), results.len);

        // Verify we found all expected files
        var found_file1 = false;
        var found_test_file = false;

        for (results) |result| {
            if (std.mem.endsWith(u8, result, path.sep_str ++ "file1.txt")) {
                found_file1 = true;
            } else if (std.mem.endsWith(u8, result, path.sep_str ++ "test_file.txt")) {
                found_test_file = true;
            }
        }

        try testing.expect(found_file1);
        try testing.expect(found_test_file);
    }
}

test "glob with negated pattern" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 0.17 threads an explicit I/O instance through every filesystem call.
    var io_state = std.Io.Threaded.init(allocator, .{});
    defer io_state.deinit();
    const io = io_state.io();

    const test_dir = try createTestDir(io, allocator);
    defer cleanupTestDir(io, test_dir) catch {};

    // Test finding files that don't match a pattern
    {
        const pattern = try path.join(allocator, &[_][]const u8{ test_dir, "**/!(*test*).*" });
        const results = try zglob.glob(io, allocator, pattern);
        defer {
            for (results) |result| {
                allocator.free(result);
            }
            allocator.free(results);
        }

        // Should find all files that don't have "test" in their name
        for (results) |result| {
            try testing.expect(std.mem.indexOf(u8, result, "test") == null);
        }
    }
}
