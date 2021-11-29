const std = @import("std");


pub fn searchDir(path: []const u8, out_step: *std.build.Step) void {
    // Search for all C/C++ files in `src` and add them
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });

    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    const allowed_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };
    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include_file = for (allowed_exts) |e| {
            if (std.mem.eql(u8, ext, e))
                break true;
        } else false;
        if (include_file) {
            // we have to clone the path as walker.next() or walker.deinit() will override/kill it
            out_step.addCSourceFile(b.dupe(entry.path), &cflags);
        }
    }
}
