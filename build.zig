const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
    });
    const optimize = b.standardOptimizeOption(.{
    });

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

    const exe = b.addExecutable(.{
        .name = "sayu",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("onnxruntime", onnx_dep.module("zig-onnxruntime"));

    const wav_mod = b.dependency("zig-soundio", .{ .target = target, .optimize = optimize }).module("wav");
    exe.root_module.addImport("wav", wav_mod);

    exe.linkLibrary(espeak.artifact("espeak-ng"));
    const espeak_include = espeak.path("include");
    exe.addIncludePath(espeak_include);

    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.root_module.addImport("onnxruntime", onnx_dep.module("zig-onnxruntime"));

    exe_unit_tests.linkLibrary(espeak.artifact("espeak-ng"));
    exe_unit_tests.addIncludePath(espeak_include);

    const phoneme_id_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/phoneme_id.zig"),
        .target = target,
        .optimize = optimize,
    });
    phoneme_id_unit_tests.linkLibrary(espeak.artifact("espeak-ng"));
    phoneme_id_unit_tests.addIncludePath(espeak_include);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const run_phoneme_id_unit_tests = b.addRunArtifact(phoneme_id_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_phoneme_id_unit_tests.step);
}
