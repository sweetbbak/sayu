//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const piper = @import("piper.zig");
const phoneme = @import("phonemize.zig");
const synth = @import("synth.zig");
const pid = @import("phoneme_id.zig");
const Allocator = std.mem.Allocator;
const logFn = @import("logger/log.zig").myLogFn;
const log = std.log;

const allocator = std.heap.c_allocator;

export fn add(
    text: [*:0]const u8,
    rate: f32,
    model: [*:0]const u8,
) callconv(.C) void {
    log.info("initializing...", .{});
    piper.synth_text(allocator, mem.span(model), @ptrCast(mem.span(text)), .{ .lengthScale = rate }, .{ .write_stdout = true }) catch unreachable;
}
