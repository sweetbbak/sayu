const std = @import("std");
const mem = std.mem;
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

pub const Options = struct {
    stdout: bool = false,
    output: ?[]const u8 = null,
    stdin: bool = false,
    input_file: ?[]const u8 = null,
    model: ?[:0]const u8 = null,
    speech_rate: ?f32 = null,
    args: ?[]const u8 = null,
};

inline fn check_arg(args: [][:0]u8, index: usize) void {
    if (index + 1 > args.len) {
        log.err("{s}: must have argument", .{args[index]});
        std.process.exit(1);
    }
    if (mem.startsWith(u8, "--", args[index + 1])) {
        log.err("{s}: must have argument - got {s}", .{ args[index], args[index + 1] });
        std.process.exit(1);
    }
}

const help_msg = \\
\\usage: sayu [opts]
\\  -h, --help           print this message
\\  -s, --stdout         write binary audio to stdout (16-bit 22050hz little endian)
\\  -o, --output <file>  write to the given wav file
\\  -i, --input  <file>  get input text from the given file
\\  -r, --rate   <float> speech rate (0-1)
\\
\\examples:
\\  sayu --rate 0.5 --stdout --input ~/00001.txt | aplay -r 22050 -c 1 -f S16_LE -t raw
;

fn print_help() void {
    std.debug.print("{s}\n", .{help_msg});
    std.process.exit(0);
}

fn parse_flags(args: [][:0]u8) !Options {
    var opts: Options = .{};

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, "--help", arg) or mem.eql(u8, "-h", arg)) {
            print_help();
        }
        if (mem.eql(u8, "--stdout", arg) or mem.eql(u8, "-s", arg)) {
            opts.stdout = true;
        }
        if (mem.eql(u8, "--output", arg) or mem.eql(u8, "-o", arg)) {
            check_arg(args, i);
            opts.output = args[i + 1];
        }
        if (mem.eql(u8, "--input", arg) or mem.eql(u8, "-i", arg)) {
            check_arg(args, i);
            opts.input_file = args[i + 1];
        }
        if (mem.eql(u8, "--model", arg) or mem.eql(u8, "-m", arg)) {
            check_arg(args, i);
            opts.model = args[i + 1];
        }
        if (mem.eql(u8, "--rate", arg) or mem.eql(u8, "-r", arg)) {
            check_arg(args, i);
            opts.speech_rate = try std.fmt.parseFloat(f32, args[i + 1]);
        }
        if (mem.startsWith(u8, "--", args[i])) {
            log.err("unknown argument {s}", .{args[i]});
            std.process.exit(1);
        } else {
            opts.args = args[i];
        }
    }

    return opts;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const opts = try parse_flags(args);

    var text: []const u8 = undefined;
    if (opts.stdin) {
        text = try std.io.getStdIn().readToEndAlloc(allocator, 1024 * 10);
    }

    if (opts.input_file) |fname| {
        const file = try std.fs.cwd().openFile(fname, .{});
        defer file.close();
        text = try file.readToEndAlloc(allocator, 1024 * 10);
    }

    var out: piper.Output = .{};

    if (opts.stdout) {
        out.write_stdout = true;
    } else if (opts.output) |outfile| {
        out.output = outfile;
    } else {
        out.output = "output.wav";
    }

    var cfg: synth.Config = .{};
    if (opts.speech_rate) |rate| {
        if (rate > 1) {
            cfg.noiseScale = @max(1 - rate, 0.1);
            cfg.lengthScale = @max(1 + rate, 1.0);
        }
        if (rate <= 1) {
            cfg.noiseScale = @max(1 + rate, 1.0);
            cfg.lengthScale = @max(1 + rate, 1.0);
        }

        cfg.lengthScale = rate;
    }

    var model: [:0]const u8 = "";
    if (opts.model) |mod| {
        model = mod;
    } else {
        print_help();
    }

    log.info("initializing...", .{});
    try piper.synth_text(allocator, model, @ptrCast(text), cfg, out);
    std.process.exit(0);
}
