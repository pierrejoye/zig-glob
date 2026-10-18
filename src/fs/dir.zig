const std = @import("std");

/// Create a directory (and its parents) relative to the current working
/// directory.
pub fn create(io: std.Io, path: []const u8) !void {
    return std.Io.Dir.cwd().createDirPath(io, path);
}

/// Remove a directory tree relative to the current working directory.
pub fn remove(io: std.Io, path: []const u8) !void {
    return std.Io.Dir.cwd().deleteTree(io, path);
}

/// Get the current working directory using the provided allocator.
///
/// The caller is responsible for freeing the returned memory.
pub fn getCwd(io: std.Io, allocator: std.mem.Allocator) ![:0]const u8 {
    return std.process.currentPathAlloc(io, allocator);
}
