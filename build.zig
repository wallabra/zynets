const std = @import("std");


fn buildLibraryStep() *std.build.LibExeObjStep {

}

pub fn addToStep(b: *std.build.Builder, step: *std.build.LibExeObjStep) void {
    step.linkLibrary(buildLibraryStep());
}

pub fn step(b: *std.build.Builder) *std.build.LibExeObjStep {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const zynets = b.addStaticLibrary("zynets", "src/main.zig");

    return zynets;
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const main_tests = b.addTest("src/test.zig");
    main_tests.setBuildMode(mode);
    main_tests.setTarget(target);
    link(b, main_tests, .{});

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    step(b);
}
