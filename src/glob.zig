const std = @import("std");
const match = @import("match.zig");
const Allocator = std.mem.Allocator;
const path = std.fs.path;
const fsModule = @import("fs.zig");
const dir = @import("fs/dir.zig");

/// zGlob struct for object-oriented glob operations
/// Uses an I/O instance to read directories, and a provided allocator for all
/// memory operations
pub const zGlob = struct {
    io: std.Io,
    allocator: Allocator,
    fs: fsModule.Fs,

    /// Initialize a new zGlob instance with the given I/O instance and allocator
    pub fn init(io: std.Io, allocator: Allocator) zGlob {
        return zGlob{
            .io = io,
            .allocator = allocator,
            .fs = fsModule.Fs.init(io, allocator),
        };
    }

    /// Glob function that finds files matching a glob pattern using the current working directory
    /// Returns a slice of matching paths that must be freed by the caller
    pub fn glob(self: zGlob, pattern: []const u8) ![][]const u8 {
        // Get the absolute path of the current working directory
        const cwd = try self.fs.getCwd();
        defer self.allocator.free(cwd);
        return self.globWithCwd(pattern, cwd);
    }

    /// Glob function with a custom current working directory. That directory must be absolute.
    /// Returns a slice of matching paths that must be freed by the caller
    pub fn globWithCwd(self: zGlob, pattern: []const u8, cwd: []const u8) ![][]const u8 {
        if (!self.fs.isAbsolutePath(cwd)) {
            return error.InvalidPath;
        }

        var matches: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (matches.items) |item| {
                self.allocator.free(item);
            }
            matches.deinit(self.allocator);
        }

        const norm_pattern = try normalizePath(self.allocator, pattern);
        defer self.allocator.free(norm_pattern);
        // Determine if this is a recursive pattern (contains **)
        const is_recursive = std.mem.indexOf(u8, norm_pattern, "**") != null;
        try self.walkAndMatchFiles(cwd, norm_pattern, &matches, is_recursive);

        return matches.toOwnedSlice(self.allocator);
    }

    /// Walk a directory and find files matching the pattern
    /// If recursive is true, will search in subdirectories
    /// If recursive is false, will only search in the immediate directory
    /// This version is a method of zGlob and uses the internal fs field
    fn walkAndMatchFiles(self: zGlob, base_dir: []const u8, pattern: []const u8, matches: *std.ArrayList([]const u8), recursive: bool) !void {
        // Special handling for "." to avoid issues with null-terminated strings
        const dir_path = if (std.mem.eql(u8, base_dir, "."))
            base_dir
        else if (std.mem.indexOfScalar(u8, base_dir, 0) != null) blk: {
            const null_pos = std.mem.indexOfScalar(u8, base_dir, 0).?;
            break :blk base_dir[0..null_pos];
        } else base_dir;
        var dir_handle = std.Io.Dir.cwd().openDir(self.io, dir_path, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound or err == error.NotDir) {
                return;
            }
            return err;
        };
        defer dir_handle.close(self.io);
        const has_path_separator = std.mem.indexOfAny(u8, pattern, "/\\") != null;
        var components: std.ArrayList([]const u8) = .empty;
        defer components.deinit(self.allocator);

        if (has_path_separator) {
            var iter = std.mem.tokenizeAny(u8, pattern, "/\\");
            while (iter.next()) |comp| {
                try components.append(self.allocator, comp);
            }
        }

        // Handle patterns with directory prefixes
        if (has_path_separator) {
            // Check if there's a directory prefix
            const first_slash = std.mem.indexOf(u8, pattern, "/");
            if (first_slash != null) {
                // Get the first directory component
                const first_dir = pattern[0..first_slash.?];

                // Iterate through directory entries to find matching first directory
                var first_level_iter = dir_handle.iterate();
                while (try first_level_iter.next(self.io)) |entry| {
                    if (entry.kind == .directory and match.globMatch(first_dir, entry.name)) {
                        // Found a matching directory, now recurse with the rest of the pattern
                        const sub_dir = try path.join(self.allocator, &[_][]const u8{ base_dir, entry.name });
                        defer self.allocator.free(sub_dir);

                        // Get the remaining pattern (after the first slash)
                        const remaining_pattern = pattern[first_slash.? + 1 ..];

                        // Recurse into the subdirectory with the remaining pattern
                        try self.walkAndMatchFiles(sub_dir, remaining_pattern, matches, recursive);
                    }
                }
                return;
            }
        }

        var iter = dir_handle.iterate();
        while (try iter.next(self.io)) |entry| {
            const full_path = try path.join(self.allocator, &[_][]const u8{ base_dir, entry.name });
            defer self.allocator.free(full_path);

            if (entry.kind == .directory) {
                if (recursive) {
                    try self.walkAndMatchFiles(full_path, pattern, matches, recursive);
                } else if (has_path_separator and components.items.len > 1) {
                    // For path patterns, check if this directory matches the first component
                    if (match.globMatch(components.items[0], entry.name)) {
                        // Recurse with the remaining pattern components
                        var new_pattern: std.ArrayList(u8) = .empty;
                        defer new_pattern.deinit(self.allocator);

                        // Skip the first component and build the new pattern
                        for (components.items[1..], 0..) |comp, i| {
                            if (i > 0) try new_pattern.append(self.allocator, '/');
                            try new_pattern.appendSlice(self.allocator, comp);
                        }

                        // Recurse into the subdirectory with the new pattern
                        try self.walkAndMatchFiles(full_path, new_pattern.items, matches, recursive);
                    }
                }
                continue;
            }

            var is_match = false;

            if (has_path_separator) {
                const rel_path = try self.getRelativePath(base_dir, full_path);
                defer self.allocator.free(rel_path);

                is_match = match.globMatch(pattern, rel_path);
            } else {
                is_match = match.globMatch(pattern, entry.name);
            }
            if (is_match) {
                const owned_path = try self.allocator.dupe(u8, full_path);
                try matches.append(self.allocator, owned_path);
            }
        }
    }

    /// Get the relative path from a base directory to a target path
    fn getRelativePath(self: zGlob, base: []const u8, target: []const u8) ![]const u8 {
        // Handle trailing separators in base path
        const clean_base = if (base.len > 0 and (base[base.len - 1] == '/' or base[base.len - 1] == '\\'))
            base[0 .. base.len - 1]
        else
            base;

        if (std.mem.startsWith(u8, target, clean_base)) {
            var rel = target[clean_base.len..];
            // Remove leading separator if present (handling both / and \)
            if (rel.len > 0 and (rel[0] == '/' or rel[0] == '\\')) {
                rel = rel[1..];
            }
            return self.allocator.dupe(u8, rel);
        }

        return self.allocator.dupe(u8, target);
    }
};

/// Glob function that finds files matching a glob pattern using the current working directory
/// Returns a slice of matching paths that must be freed by the caller
pub fn glob(io: std.Io, allocator: Allocator, pattern: []const u8) ![][]const u8 {
    // Create a temporary zGlob instance
    var zglob = zGlob.init(io, allocator);

    // Get the absolute path of the current working directory
    const fs_helper = fsModule.Fs.init(io, allocator);
    const cwd = try fs_helper.getCwd();
    defer allocator.free(cwd);

    // Use the absolute path with globWithCwd
    return zglob.globWithCwd(pattern, cwd);
}

/// Glob function with a custom current working directory
/// Returns a slice of matching paths that must be freed by the caller
pub fn globWithCwd(io: std.Io, allocator: Allocator, pattern: []const u8, cwd: []const u8) ![][]const u8 {
    // Create a temporary zGlob instance
    var zglob = zGlob.init(io, allocator);

    // If the path is not absolute, convert it to an absolute path
    const fs_helper = fsModule.Fs.init(io, allocator);
    if (!fs_helper.isAbsolutePath(cwd)) {
        // Get the current working directory
        const current_dir = try fs_helper.getCwd();
        defer allocator.free(current_dir);

        // If cwd is "." just use the current directory
        if (std.mem.eql(u8, cwd, ".")) {
            return zglob.globWithCwd(pattern, current_dir);
        }

        // Join the current directory with the provided path
        const abs_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_dir, cwd });
        defer allocator.free(abs_path);

        // Use the zGlob's globWithCwd method with the absolute path
        return zglob.globWithCwd(pattern, abs_path);
    }

    // Use the zGlob's globWithCwd method directly since cwd is already absolute
    return zglob.globWithCwd(pattern, cwd);
}

/// Normalizes a path string by replacing backslashes with forward slashes
fn normalizePath(allocator: Allocator, p: []const u8) ![]const u8 {
    var result = try allocator.alloc(u8, p.len);
    errdefer allocator.free(result);

    for (p, 0..) |c, i| {
        result[i] = if (c == '\\') '/' else c;
    }

    return result;
}

// The walkAndFindMatches and getRelativePath functions have been moved into the zGlob struct
