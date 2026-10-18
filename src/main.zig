const std = @import("std");
const zglob = @import("zglob");
const unicode = std.unicode;

const isWindows = @import("builtin").os.tag == .windows;

/// For debugging purposes
fn dumpPath(path: []const u8) void {
    std.debug.print("Path dump: ", .{});
    for (path) |c| {
        std.debug.print("{c}({d}) ", .{ c, c });
    }
    std.debug.print("\n", .{});
}

pub fn main(init: std.process.Init) !void {
    // On 0.17 the entry point is handed the I/O instance and the arguments, and
    // a file writer is buffered, so both streams are flushed on the way out.
    var stdout_buf: [4096]u8 = undefined;
    var stderr_buf: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout().writer(init.io, &stdout_buf);
    var stderr_file = std.Io.File.stderr().writer(init.io, &stderr_buf);
    const stdout = &stdout_file.interface;
    const stderr = &stderr_file.interface;
    defer stdout_file.interface.flush() catch |err| {
        std.debug.print("zglob: failed to flush stdout: {s}\n", .{@errorName(err)});
    };
    defer stderr_file.interface.flush() catch |err| {
        std.debug.print("zglob: failed to flush stderr: {s}\n", .{@errorName(err)});
    };

    // 0.17 hands a general purpose allocator and an arena to main, so there is
    // no allocator boilerplate left to write here.
    const allocator = init.arena.allocator();

    // Create a zGlob instance to use its filesystem functionality
    var glob = zglob.zGlob.init(init.io, allocator);

    var args = try std.process.Args.iterateAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.next();

    // Check command line mode
    const first_arg = args.next() orelse {
        try stderr.writeAll("Usage:\n");
        try stderr.writeAll("  zglob match <glob_pattern> <path>   - Test if a path matches a pattern\n");
        try stderr.writeAll("  zglob find <glob_pattern> [path]    - Find files matching a pattern\n");
        return;
    };

    // Use the same glob instance that we created earlier
    const cwd = try glob.fs.getCwd();
    defer allocator.free(cwd);

    if (std.mem.eql(u8, first_arg, "match")) {
        // Match mode - test if a path matches a pattern
        const glob_pattern = args.next() orelse {
            try stderr.writeAll("Usage: zglob match <glob_pattern> <path>\n");
            return;
        };

        const path = args.next() orelse {
            try stderr.writeAll("Usage: zglob match <glob_pattern> <path>\n");
            return;
        };

        const result = zglob.globMatch(glob_pattern, path);

        try stdout.print("Pattern: {s}\nPath: {s}\nResult: {}\n", .{ glob_pattern, path, result });

        if (result) {
            if (zglob.globMatchWithCaptures(glob_pattern, path, allocator)) |maybe_captures| {
                var captures = maybe_captures;
                defer captures.deinit(allocator);

                try stdout.print("Captures ({d}):\n", .{captures.items.len});
                for (captures.items, 0..) |capture, i| {
                    try stdout.print("  {d}: {s}\n", .{ i, path[capture.start..capture.end] });
                }
            }
        }
    } else if (std.mem.eql(u8, first_arg, "find")) {
        // Find mode - find files matching a pattern
        const glob_pattern = args.next() orelse {
            try stderr.writeAll("Usage: zglob find <glob_pattern> [path]\n");
            return;
        };

        const search_path = args.next() orelse cwd;

        // Handle relative paths correctly by using normalizePath with the CWD as base
        // For absolute paths, just use them directly
        const search_path_abs = if (glob.fs.isAbsolutePath(search_path))
            try allocator.dupe(u8, search_path)
        else
            try glob.fs.normalizePath(cwd, search_path, .{});
        defer allocator.free(search_path_abs);

        const matches = try glob.globWithCwd(glob_pattern, search_path_abs);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.print("Found {d} matches:\n", .{matches.len});
        for (matches, 0..) |match_path, i| {
            try stdout.print("{d}: {s}\n", .{ i + 1, match_path });
        }
    } else {
        try stderr.writeAll("Unknown command. Use 'match' or 'find'.\n");
        try stderr.writeAll("Usage:\n");
        try stderr.writeAll("  zglob match <glob_pattern> <path>   - Test if a path matches a pattern\n");
        try stderr.writeAll("  zglob find <glob_pattern> [path]    - Find files matching a pattern\n");
    }
}

test "simple test" {
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(std.testing.allocator);
    try list.append(std.testing.allocator, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
