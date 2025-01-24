const std = @import("std");
const phoneme = @import("phonemize.zig");
const synth = @import("synth.zig");
const pid = @import("phoneme_id.zig");
const log = @import("std").log;
const logFn = @import("logger/log.zig").myLogFn;

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
const phoneme_ids: []const i64 = &.{ 1, 0, 20, 0, 121, 0, 14, 0, 100, 0, 3, 0, 51, 0, 122, 0, 88, 0, 3, 0, 22, 0, 33, 0, 122, 0, 3, 0, 17, 0, 120, 0, 33, 0, 122, 0, 74, 0, 44, 0, 13, 0, 2 };

/// read every line from stdin into a list
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

/// read phoneme IDs from stdin and play them
pub fn phonemes_from_stdin() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const output = try read_stdin(allocator);
    try synth.load_model(allocator, model_path, output, .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    log.info("phonemizing: {s}\n", .{args[1]});
    const output = try phoneme.Phonemize(allocator, args[1], .{ .voice = "en", .mode = .IPA_MODE });
    defer allocator.free(output);

    std.debug.print("{any}\n", .{output});

    for (output) |value| {
        const _ids = try pid.phonemes_to_ids(allocator, value, .{});
        std.debug.print("{any}\n", .{_ids});
        try synth.load_model(allocator, model_path, _ids, .{});
    }
}
