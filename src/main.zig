const std = @import("std");
const piper = @import("piper.zig");
const phoneme = @import("phonemize.zig");
const synth = @import("synth.zig");
const pid = @import("phoneme_id.zig");
const Allocator = std.mem.Allocator;
const logFn = @import("logger/log.zig").myLogFn;
const log = std.log;

pub const std_options: std.Options = .{
    .logFn = logFn,
    .log_level = .debug,
};

const IPA_MODE = 0x2;

pub fn opaqPtrTo(ptr: ?*anyopaque, comptime T: type) T {
    return @ptrCast(@alignCast(ptr));
}

const model_path: [:0]const u8 = "/home/sweet/ssd/pipertts/ivona_tts/amy.onnx";
// const model_path: [:0]const u8 = "./kokoro-v0_19.onnx";

// "How are you doing?" phoneme IDs
const hey_phoneme_ids: []const i64 = &.{ 1, 0, 20, 0, 121, 0, 14, 0, 100, 0, 3, 0, 51, 0, 122, 0, 88, 0, 3, 0, 22, 0, 33, 0, 122, 0, 3, 0, 17, 0, 120, 0, 33, 0, 122, 0, 74, 0, 44, 0, 13, 0, 2 };

// fn parse_flags(args: [][:0]u8) !void {
// }

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    log.info("phonemizing: {s}\n", .{args[1]});

    try piper.synth_text(
        allocator,
        model_path,
        args[1],
        .{},
        .{ .output = "output.wav" }
    );

    // var output = try phoneme.Phonemize(allocator, args[1], .{ .voice = "en", .mode = .IPA_MODE });
    // defer output.deinit();
    //
    // const lines = try output.toSlice();
    //
    // for (lines) |value| {
    //     const _ids = try pid.phonemes_to_ids(allocator, value, .{});
    //     defer allocator.free(_ids);
    //
    //     try synth.load_model(allocator, model_path, _ids, .{
    //         .lengthScale = 0.67,
    //         .noiseW = 0.6,
    //         .sentenceSilenceSeconds = 0.1,
    //     });
    // }
}
