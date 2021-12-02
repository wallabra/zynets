const std = @import("std");


pub fn addToStep(b: *std.build.Builder, step: *std.build.LibExeObjStep) void {
    step.linkLibrary(step(b));
}

pub fn step(b: *std.build.Builder) *std.build.LibExeObjStep {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const zynets = b.addStaticLibrary("zynets", "src/main.zig");
    zynets.setBuildMode(mode);
    zynets.setTarget(target);

    return zynets;
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const libStep = step(b);
    libStep.install();

    const main_tests = b.addTest("src/test.zig");
    main_tests.setBuildMode(mode);
    main_tests.setTarget(target);
    main_tests.dependOn(libStep);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
