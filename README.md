# glob and match Zig implementation


A Zig library for file globbing and pattern matching with support for common glob syntax.

This is my 1st zig project. I am sure many things may be done differently to fit the good practices and the likes. PRs are more than welcome!

The primary focus was to get the glob and matching working correctly. APIs and commmand line tool will change to match more standard glob implementation naming.

I used [picomatch](https://github.com/micromatch/picomatch) picomatch as a reference. And the excellent [glob-match](https://github.com/devongovett/glob-match).

## Build

Requires Zig 0.17.0 or later: filesystem calls take an `std.Io` instance, which is
what `std.process.Init` hands to `main`.

```bash
zig build
```

## Tests
```bash
zig build test
```

## Cross build for Windows

```bash
zig build -Dtarget=x86_64-windows -fwine   
```

## Run tests using Wine

```bash
zig build test -Dtarget=x86_64-windows -fwine  
```

## API

The zglob library provides both functional and object-oriented APIs for glob matching and file searching.

### Pattern Matching

```zig
// Check if a path matches a glob pattern
pub fn globMatch(pattern: []const u8, path: []const u8) bool

// Check if a path matches a glob pattern and capture wildcards
pub fn globMatchWithCaptures(pattern: []const u8, path: []const u8, allocator: std.mem.Allocator) ?std.ArrayList(Capture)

// A capture range representing a matched wildcard
pub const Capture = struct {
    start: usize,  // Start byte index in the path
    end: usize,    // End byte index in the path
};

// Object-oriented pattern matcher
pub const MatchGlob = struct {
    // Initialize a new matcher with an allocator
    pub fn init(allocator: std.mem.Allocator) MatchGlob
    
    // Match a pattern against a path
    pub fn match(self: MatchGlob, pattern: []const u8, path: []const u8) bool
    
    // Match a pattern and get captures
    pub fn matchWithCaptures(self: MatchGlob, pattern: []const u8, path: []const u8) ?std.ArrayList(Capture)
};
```

### File Globbing

```zig
// Find files matching a pattern using the current working directory
pub fn glob(io: std.Io, allocator: std.mem.Allocator, pattern: []const u8) ![][]const u8

// Find files matching a pattern using a specific directory as base
pub fn globWithCwd(io: std.Io, allocator: std.mem.Allocator, pattern: []const u8, cwd: []const u8) ![][]const u8

// Object-oriented file globber
pub const zGlob = struct {
    // Initialize a new globber with an I/O instance and an allocator
    pub fn init(io: std.Io, allocator: std.mem.Allocator) zGlob
    
    // Find files matching a pattern using the current working directory
    pub fn glob(self: zGlob, pattern: []const u8) ![][]const u8
    
    // Find files matching a pattern using a specific directory as base
    pub fn globWithCwd(self: zGlob, pattern: []const u8, cwd: []const u8) ![][]const u8
};
```

### Filesystem Utilities

```zig
// Filesystem helper struct
pub const Fs = struct {
    // Initialize with an I/O instance and an allocator
    pub fn init(io: std.Io, allocator: std.mem.Allocator) Fs
    
    // Get the current working directory
    pub fn getCwd(self: Fs) ![]const u8
    
    // Join paths with appropriate separators
    pub fn joinPath(self: Fs, paths: []const []const u8) ![]const u8
    
    // Check if a path is absolute
    pub fn isAbsolutePath(self: Fs, path: []const u8) bool
};
```

### Glob Pattern Syntax

The library supports the following glob patterns:

- `*`: Matches any sequence of characters except path separators
- `?`: Matches exactly one character except path separator
- `**`: Matches any sequence of characters including path separators
- `[abc]`: Matches any character in the brackets
- `[a-z]`: Matches any character in the given range
- `[!abc]` or `[^abc]`: Matches any character not in the brackets
- `{a,b,c}`: Matches any of the comma-separated patterns
- `\`: Escapes the next character, removing its special meaning

## Examples

Check out the `examples` directory for more usage examples:

- `basic_glob_usage.zig`: Demonstrates basic file globbing
- `pattern_matching.zig`: Demonstrates pattern matching with different glob syntax
- `allocator_usage.zig`: Shows how to use different allocators with zglob

## Examples

### Pattern Matching Example

```zig
const std = @import("std");
const zglob = @import("zglob");

test "Basic pattern matching" {
    // Simple exact match
    try std.testing.expect(zglob.globMatch("file.txt", "file.txt"));
    
    // Wildcard matching
    try std.testing.expect(zglob.globMatch("*.txt", "file.txt"));
    try std.testing.expect(!zglob.globMatch("*.md", "file.txt"));
    
    // Character classes
    try std.testing.expect(zglob.globMatch("file.[tm]xt", "file.txt"));
    try std.testing.expect(!zglob.globMatch("file.[abc]xt", "file.txt"));
    
    // Path matching
    try std.testing.expect(zglob.globMatch("src/**/*.zig", "src/fs/dir.zig"));
    
    // Brace expansion
    try std.testing.expect(zglob.globMatch("file.{txt,md}", "file.txt"));
    try std.testing.expect(zglob.globMatch("file.{txt,md}", "file.md"));
    try std.testing.expect(!zglob.globMatch("file.{txt,md}", "file.js"));
}
```

### Globbing Files Example

```zig
const std = @import("std");
const zglob = @import("zglob");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    
    // Find all Zig files in the src directory
    const matches = try zglob.glob(init.io, allocator, "src/*.zig");
    defer {
        for (matches) |match_path| {
            allocator.free(match_path);
        }
        allocator.free(matches);
    }
    
    // Print the results
    for (matches) |match_path| {
        std.debug.print("{s}\n", .{match_path});
    }
}
```

## Complete API Reference

### zglob Module

The main module exports these functions and types:

```zig
// Pattern matching functions
pub fn globMatch(pattern: []const u8, path: []const u8) bool
pub fn globMatchWithCaptures(pattern: []const u8, path: []const u8, allocator: std.mem.Allocator) ?std.ArrayList(Capture)
pub const Capture = struct { start: usize, end: usize }
pub const MatchGlob = struct { ... }

// File finding functions
pub fn glob(io: std.Io, allocator: std.mem.Allocator, pattern: []const u8) ![][]const u8
pub fn globWithCwd(io: std.Io, allocator: std.mem.Allocator, pattern: []const u8, cwd: []const u8) ![][]const u8
pub const zGlob = struct { ... }

// Filesystem utilities
pub const Fs = struct { ... }
pub const fs = struct { ... }
```

### zglob.fs Module

The filesystem module provides utilities for handling paths:

```zig
pub const Fs = struct {
    io: std.Io,
    allocator: std.mem.Allocator,

    // Create a new Fs instance
    pub fn init(io: std.Io, allocator: std.mem.Allocator) Fs

    // Get the current working directory
    pub fn getCwd(self: Fs) ![]const u8

    // Join path components with appropriate separators
    pub fn joinPath(self: Fs, paths: []const []const u8) ![]const u8

    // Check if a path is absolute
    pub fn isAbsolutePath(self: Fs, path: []const u8) bool

    // Normalize a path by converting backslashes to forward slashes
    pub fn normalizePath(self: Fs, path: []const u8) ![]const u8

    // Directory operations
    pub const Dir = struct { ... }

    // Path manipulation utilities
    pub const Path = struct { ... }
};
```

### Memory Management

All functions that return allocated memory require the caller to free that memory when done. The examples demonstrate proper memory management practices.

When using the library:

1. Always pass an appropriate allocator based on your program's lifecycle
2. Use `defer` to ensure memory is properly freed
3. For multiple allocations (like array of strings), remember to free each item before freeing the container