const std = @import("std");
const zglob = @import("zglob");

pub fn main(init: std.process.Init) !void {
    // 0.17 hands an arena and an I/O instance to main, and a file writer is
    // buffered, so it is flushed on the way out.
    const allocator = init.arena.allocator();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout_writer.interface.flush() catch |err| {
        std.debug.print("basic-glob-usage: failed to flush stdout: {s}\n", .{@errorName(err)});
    };

    // Simple pattern matching
    {
        try stdout.print("\n--- Simple pattern matching ---\n", .{});
        const pattern = "src/*.zig";
        try stdout.print("Finding files matching pattern: {s}\n", .{pattern});

        const matches = try zglob.glob(init.io, allocator, pattern);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.print("Found {d} matches:\n", .{matches.len});
        for (matches) |match_path| {
            try stdout.print("  {s}\n", .{match_path});
        }
    }

    // Recursive pattern matching
    {
        try stdout.print("\n--- Recursive pattern matching ---\n", .{});
        const pattern = "**/*.zig";
        try stdout.print("Finding files matching pattern: {s}\n", .{pattern});

        const matches = try zglob.glob(init.io, allocator, pattern);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.print("Found {d} matches (showing first 5):\n", .{matches.len});
        const limit = @min(matches.len, 5);
        for (matches[0..limit]) |match_path| {
            try stdout.print("  {s}\n", .{match_path});
        }
        if (matches.len > 5) {
            try stdout.print("  ... and {d} more files\n", .{matches.len - 5});
        }
    }

    // Using the struct API
    {
        try stdout.print("\n--- Using the struct API ---\n", .{});
        const pattern = "src/fs/*.zig";
        try stdout.print("Finding files matching pattern: {s}\n", .{pattern});

        const glob_finder = zglob.zGlob.init(init.io, allocator);
        const matches = try glob_finder.glob(pattern);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.print("Found {d} matches:\n", .{matches.len});
        for (matches) |match_path| {
            try stdout.print("  {s}\n", .{match_path});
        }
    }
}
