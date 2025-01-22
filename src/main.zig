const std = @import("std");
const phoneme = @import("phonemize.zig");
const synth = @import("synth.zig");
// const onnx = @import("onnxruntime");

const c = @cImport({
    @cInclude("espeak-ng/speak_lib.h");
});

const IPA_MODE = 0x2;

pub fn opaqPtrTo(ptr: ?*anyopaque, comptime T: type) T {
    return @ptrCast(@alignCast(ptr));
}

const model_path: [:0]const u8 = "/home/sweet/ssd/pipertts/ivona_tts/amy.onnx";
const phoneme_ids: []const i64 = &.{
    1,
    0,
    20,
    0,
    121,
    0,
    14,
    0,
    100,
    0,
    3,
    0,
    51,
    0,
    122,
    0,
    88,
    0,
    3,
    0,
    22,
    0,
    33,
    0,
    122,
    0,
    3,
    0,
    17,
    0,
    120,
    0,
    33,
    0,
    122,
    0,
    74,
    0,
    44,
    0,
    13,
    0,
    2,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const s: [:0]const u8 = "How are you doing? I am fine! Okay, then.";
    const str: [:0]u8 = try allocator.dupeZ(u8, s);
    defer allocator.free(str);

    const output = try phoneme.Phonemize(allocator, str, .{ .voice = "en" });
    defer allocator.free(output);

    const pids = try allocator.dupe(i64, phoneme_ids);
    defer allocator.free(pids);

    try synth.load_model(allocator, model_path, pids, .{});

    // std.debug.print("output:\n", .{});
    // for (output) |value| {
    //     std.debug.print("sentence: \n{s}\n", .{value});
    //     for (value) |p| {
    //         std.debug.print("{d}\n", .{p});
    //     }
    // }
}

pub fn test_it() !void {
    const buflen = 500;
    const options = 0;

    const exit = c.espeak_Initialize(c.AUDIO_OUTPUT_SYNCH_PLAYBACK, buflen, null, options);
    if (exit < 0) return error.Init;
    defer {
        _ = c.espeak_Terminate();
    }

    // const voice: [:0]const u8 = "English";
    const voice: [:0]const u8 = "en-us";
    if (c.espeak_SetVoiceByName(@ptrCast(voice)) < 0) {
        return error.SetVoice;
    }

    const id: [*c]c_uint = 0;
    const uid: ?*anyopaque = null;

    // std.debug.print("saying '{s}'\n", .{@as([]const u8, @ptrCast(text))});
    // _ = c.espeak_Synth(text, 500, 0, 0, 0, c.espeakCHARS_AUTO, id, uid);
    _ = c.espeak_Synth(null, 500, 0, 0, 0, c.espeakCHARS_AUTO, id, uid);

    var _str: ?*const anyopaque = "hello world.";
    const _cstr = c.espeak_TextToPhonemes(&_str, c.espeakCHARS_UTF8, 0x2);
    std.debug.print("{s}\n", .{std.mem.span(_cstr)});

    // const str = try allocator.dupeZ(u8, "hello world.");
    // defer allocator.free(str);
    // var str_ptr: ?*const anyopaque = str.ptr;

    // const cstr = c.espeak_TextToPhonemes(&str_ptr, c.espeakCHARS_8BIT, IPA_MODE);
    // std.debug.print("{s}\n", .{std.mem.span(cstr)});
}
