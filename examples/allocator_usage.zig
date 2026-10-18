const std = @import("std");
const zglob = @import("zglob");

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout_writer.interface.flush() catch |err| {
        std.debug.print("allocator-usage-example: failed to flush stdout: {s}\n", .{@errorName(err)});
    };

    // Example 1: Using default page_allocator
    {
        const fs_helper = zglob.fs.Fs.init(init.io, std.heap.page_allocator);
        const cwd = try fs_helper.getCwd();
        defer std.heap.page_allocator.free(cwd); // Must free with page_allocator
        try stdout.print("Example 1 - Default allocator: Current directory: {s}\n", .{cwd});
    }

    // Example 2: Using arena allocator (best for short-lived programs)
    {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit(); // This frees ALL memory allocated by the arena

        const allocator = arena.allocator();
        const fs_helper = zglob.fs.Fs.init(init.io, allocator);
        const cwd = try fs_helper.getCwd();
        // No need to free cwd here - arena.deinit() will free everything at once

        try stdout.print("Example 2 - Arena allocator: Current directory: {s}\n", .{cwd});
    }

    // Example 3: Using the general purpose allocator that the runtime provides
    // (best for long-running programs)
    {
        const allocator = init.gpa;
        const fs_helper = zglob.fs.Fs.init(init.io, allocator);
        const cwd = try fs_helper.getCwd();
        defer allocator.free(cwd);

        try stdout.print("Example 3 - GPA: Current directory: {s}\n", .{cwd});
    }

    // Example 4: Using the zGlob struct with the GPA
    {
        try stdout.print("\nzGlob examples with different allocators:\n", .{});

        const allocator = init.gpa;

        // Create a zGlob instance with the runtime's I/O and the GPA
        var glob = zglob.zGlob.init(init.io, allocator);

        // Use the glob function
        try stdout.print("Searching for *.zig files in the current directory...\n", .{});
        const results = try glob.glob("*.zig");
        defer {
            for (results) |path| {
                allocator.free(path);
            }
            allocator.free(results);
        }

        for (results) |path| {
            try stdout.print("Found: {s}\n", .{path});
        }
    }

    // Example 5: Using the zGlob struct with an arena allocator
    {
        try stdout.print("\nUsing zGlob with an arena allocator (no manual memory management needed):\n", .{});

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit(); // This will free ALL memory at once

        const allocator = arena.allocator();

        // Create a zGlob instance with the runtime's I/O and the arena allocator
        var glob = zglob.zGlob.init(init.io, allocator);

        // Use the glob function
        try stdout.print("Searching for src/*.zig files...\n", .{});
        const results = try glob.glob("src/*.zig");
        // No need to free anything manually!

        for (results) |path| {
            try stdout.print("Found: {s}\n", .{path});
        }
    }
}
