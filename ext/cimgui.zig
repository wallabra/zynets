const std = @import("std");
const extcommon = @import("extcommon.zig");
const glfw = @import("glfw.zig");


const cflags = [_][]const u8;

pub fn addToStep(b: *std.build.Builder, step: std.build.LibExeObjStep) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    step.linkLibC();
    step.linkLibCpp();

    // MNT: ensure cimgui sources list is always up to date
    step.addCSourceFile("cimgui/cimgui.cpp", &cflags);
    step.addCSourceFiles([_][]const u8 {
        "cimgui/imgui/imgui_draw.cpp",
        "cimgui/imgui/imgui_demo.cpp",
        "cimgui/imgui/backends/imgui_impl_glfw.cpp",
        "cimgui/imgui/backends/imgui_impl_opengl3.cpp",
        "cimgui/imgui/imgui_impl_.cpp",
        "cimgui/imgui/imgui_tables.cpp",
        "cimgui/imgui/imgui_widgets.cpp"
    }, &cflags);

    step.addPackagePath("cimgui", "cimgui-index.zig");

    // Pull in GLFW dependency
    glfw.addToStep(b, step);
}
