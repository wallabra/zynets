const std = @import("std");
const extcommon = @import("extcommon.zig");
const glfw = @import("mach-glfw/build.zig");


const cflags = [_][]const u8;

pub fn addToStep(b: *std.build.Builder, step: std.build.LibExeObjStep) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    // { glfw }
    step.addPackagePath("glfw", "mach-glfw/src/main.zig");
    glfw.link(b, step, .{});
}
