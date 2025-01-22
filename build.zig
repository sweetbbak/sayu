const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "tts",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const onnx_dep = b.dependency("onnxruntime.zig", .{
        .target = target,
        .optimize = optimize,
    });

    const espeak = b.dependency("espeak", .{
        .target = target,
        .optimize = optimize,
        .strip = true,
        .pie = true,
    });

    // b.installDirectory(.{
    //     .source_dir = espeak.path("src/include/espeak-ng"),
    //     .install_dir = .header,
    //     .install_subdir = "include",
    // });

    const exe = b.addExecutable(.{
        .name = "tts",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("onnxruntime", onnx_dep.module("zig-onnxruntime"));
    // exe.linkSystemLibrary("sndfile");
    exe.linkLibrary(espeak.artifact("espeak-ng"));
    const hpath = espeak.path("include");
    exe.addIncludePath(hpath);

    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const phoneme_id_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/phoneme_id.zig"),
        .target = target,
        .optimize = optimize,
    });
    phoneme_id_unit_tests.linkLibrary(espeak.artifact("espeak-ng"));
    phoneme_id_unit_tests.addIncludePath(hpath);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const run_phoneme_id_unit_tests = b.addRunArtifact(phoneme_id_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_phoneme_id_unit_tests.step);
}
