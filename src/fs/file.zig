const std = @import("std");

// Re-export the getCwd function
pub const getCwd = @import("./dir.zig").getCwd;

// Other filesystem operations
pub fn exists(io: std.Io, path: []const u8) bool {
    return std.Io.Dir.accessAbsolute(io, path, .{}) == .{};
}

pub fn isFile(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .file;
}
