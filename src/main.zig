const std = @import("std");
const phoneme = @import("phonemize.zig");
const synth = @import("synth.zig");
const pid = @import("phoneme_id.zig");
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

pub fn read_stdin(allocator: std.mem.Allocator) ![]i64 {
    const reader = std.io.getStdIn().reader();
    var bufio = std.io.bufferedReader(reader);
    const stdin = bufio.reader();
    var buf: [10]u8 = undefined;

    var list = std.ArrayList(i64).init(allocator);
    defer list.deinit();

    while (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        const int = try std.fmt.parseInt(i64, line, 10);
        try list.append(int);
    }

    return list.toOwnedSlice();
}

pub fn _main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // const s: [:0]const u8 = "How are you doing? I am fine! Okay, then.";
    // const str: [:0]u8 = try allocator.dupeZ(u8, s);
    // defer allocator.free(str);
    //
    // const output = try phoneme.Phonemize(allocator, str, .{ .voice = "en" });
    // defer allocator.free(output);
    //
    // for (output) |value| {
    //     std.debug.print(" {d}\n", .{value});
    // }

    const output = try read_stdin(allocator);

    // const pids = try allocator.dupe(i64, phoneme_ids);
    // defer allocator.free(pids);
    // try synth.load_model(allocator, model_path, pids, .{});

    // try synth.load_model(allocator, model_path, output.ids, .{});
    try synth.load_model(allocator, model_path, output, .{});

    // std.debug.print("output:\n", .{});
    // for (output) |value| {
    //     std.debug.print("sentence: \n{s}\n", .{value});
    //     for (value) |p| {
    //         std.debug.print("{d}\n", .{p});
    //     }
    // }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const s: [:0]const u8 = "How are you doing?";
    const str: [:0]u8 = try allocator.dupeZ(u8, s);
    defer allocator.free(str);

    // std.debug.print("phonemizing: {s}\n", .{args[1]});
    // const output = try phoneme.Phonemize(allocator, args[1], .{ .voice = "en", .mode = .IPA_MODE });

    std.debug.print("phonemizing: {s}\n", .{str});
    const output = try phoneme.Phonemize2(allocator, str, .{ .voice = "en", .mode = .IPA_MODE });
    defer allocator.free(output);

    const _ids = try pid.phonemes_to_ids(allocator, output[0], .{});
    for (_ids, 0..) |value, i| {
        std.debug.print("mine: {d} piper: {d}\n", .{ value, phoneme_ids[i] });
    }

    for (output) |value| {
        std.debug.print("main: {s}\n", .{value});
        const ids = try pid.phonemes_to_ids(allocator, value, .{});

        for (ids) |_c| {
            std.debug.print("{d}\n", .{_c});
        }

        try synth.load_model(allocator, model_path, ids, .{});
    }

    // for (output) |value| {
    // defer allocator.free(value);
    // }

    // std.debug.print("{any}\n", .{output});

    // try synth.load_model(allocator, model_path, output, .{});
}

// test "matching phonemes" {
//     const allocator = std.testing.allocator;
//
//     const s: [:0]const u8 = "How are you doing?";
//     const str: [:0]u8 = try allocator.dupeZ(u8, s);
//     defer allocator.free(str);
//
//     const output = try phoneme.Phonemize(allocator, str, .{ .voice = "en" });
//     defer allocator.free(output);
//
//     for (output) |value| {
//         std.debug.print(" {d}\n", .{value});
//     }
//
//     const pids = try allocator.dupe(i64, phoneme_ids);
//     defer allocator.free(pids);
//
//     std.debug.print("pids len: {d}\n", .{pids.len});
//     std.debug.print("pids other len: {d}\n", .{output.len});
//
//     try std.testing.expectEqualDeep(output, pids);
// }
