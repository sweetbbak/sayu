// imported and modified from https://github.com/4zv4l/zig_colored_logger MIT
const std = @import("std");
const time = @import("time.zig");
const project_name = "sayu";

const esc = "\x1B";
pub const csi = esc ++ "[";
pub const reset = csi ++ "0m";
const COLOR_BUF_SIZE = 24;

/// simple 8 bit ansi colors for convenience
pub const Ansi = struct {
    pub const bg_default = csi ++ "49" ++ "m";
    pub const bg_black = csi ++ "40" ++ "m";
    pub const bg_red = csi ++ "41" ++ "m";
    pub const bg_green = csi ++ "42" ++ "m";
    pub const bg_yellow = csi ++ "43" ++ "m";
    pub const bg_blue = csi ++ "44" ++ "m";
    pub const bg_magenta = csi ++ "45" ++ "m";
    pub const bg_cyan = csi ++ "46" ++ "m";
    pub const bg_white = csi ++ "47" ++ "m";

    pub const default = csi ++ "39" ++ "m";
    pub const black = csi ++ "30" ++ "m";
    pub const red = csi ++ "31" ++ "m";
    pub const green = csi ++ "32" ++ "m";
    pub const yellow = csi ++ "33" ++ "m";
    pub const blue = csi ++ "34" ++ "m";
    pub const magenta = csi ++ "35" ++ "m";
    pub const cyan = csi ++ "36" ++ "m";
    pub const white = csi ++ "37" ++ "m";
    pub const grey = csi ++ "90m";

    pub const italic = csi ++ "3m";
    pub const bold = csi ++ "1m";
    pub const underline = csi ++ "4m";
    pub const invert = csi ++ "7m";
    pub const reset = csi ++ "0m";
};

// custom logging function
pub fn myLogFn(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    // const level_txt = comptime switch (message_level) {
    //     .warn => Ansi.yellow ++ "[WARN]" ++ Ansi.reset,
    //     .info => Ansi.blue ++ "[INFO]" ++ Ansi.reset,
    //     .debug => Ansi.green ++ "[DEBUG]" ++ Ansi.reset,
    //     .err => Ansi.red ++ "[ERROR]" ++ Ansi.reset,
    // };
    const level_txt = comptime switch (message_level) {
        .warn => Ansi.yellow ++ "WARN" ++ Ansi.reset,
        .info => Ansi.blue ++ "INFO" ++ Ansi.reset,
        .debug => Ansi.green ++ "DEBUG" ++ Ansi.reset,
        .err => Ansi.red ++ "ERROR" ++ Ansi.reset,
    };

    const prefix2 = if (scope == .default) " " else "(" ++ @tagName(scope) ++ ") ";
    const stderr = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        // 2024-09-23T08:27:16Z
        writer.writeAll(Ansi.bold ++ "[") catch return;
        time.DateTime.now().format("YYY-MM-DD HH:mm:ss", .{}, writer) catch return;
        writer.writeAll("]") catch return;
        writer.print(Ansi.reset ++ " [" ++ Ansi.green ++ Ansi.bold ++ project_name ++ Ansi.reset ++ "] " ++ level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
        bw.flush() catch return;
    }
}
