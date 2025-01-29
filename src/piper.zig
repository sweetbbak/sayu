const std = @import("std");
const id = @import("phoneme_id.zig");
const cfg = @import("config.zig");
const phoneme = @import("phonemize.zig");
const synth = @import("synth.zig");
const pid = @import("phoneme_id.zig");
const wav = @import("wav");

const Allocator = std.mem.Allocator;
const logFn = @import("logger/log.zig").myLogFn;
const log = std.log;

pub const SpeakerId = u64;
pub const PhonemeId = i64;

pub const MAX_WAV_VALUE: f32 = 32767.0;

pub const PiperConfig = struct {
    eSpeakDataPath: []const u8,
    useESpeak: bool = true,
};

pub const PhonemizeConfig = struct {
    // phonemeType: PhonemeType = eSpeakPhonemes,
    // std::optional<std::map<Phoneme, std::vector<Phoneme>>> phonemeMap;
    // std::map<Phoneme, std::vector<PhonemeId>> phonemeIdMap;

    idPad: PhonemeId = 0, // padding (optionally interspersed)
    idBos: PhonemeId = 1, // beginning of sentence
    idEos: PhonemeId = 2, // end of sentence
    interspersePad: bool = true,

    eSpeak: eSpeakConfig,
};

pub const Voice = struct {
    // json configRoot;
    phonemizeConfig: PhonemizeConfig,
    synthesisConfig: SynthesisConfig,
    modelConfig: ModelConfig,
};

pub const eSpeakConfig = struct {
    voice: []const u8 = "en-us",
};

pub const PhonemeType = enum { eSpeakPhonemes, TextPhonemes };

pub const SynthesisConfig = struct {
    // VITS inference settings
    noiseScale: f64 = 0.667,
    lengthScale: f64 = 1.0,
    noiseW: f64 = 0.8,

    // Audio settings
    sampleRate: u16 = 22050,
    sampleWidth: u8 = 2, // 16-bit
    channels: u8 = 1, // mono

    // Speaker id from 0 to numSpeakers - 1
    // std::optional<SpeakerId> speakerId;

    // Extra silence
    sentenceSilenceSeconds: f64 = 0.2,
    // std::optional<std::map<piper::Phoneme, float>> phonemeSilenceSeconds;
};

pub const ModelConfig = struct {
    numSpeakers: u8,
    // speaker name -> id
    // std::optional<std::map<std::string, SpeakerId>> speakerIdMap;
};

pub const SynthesisResult = struct {
    inferSeconds: f64,
    audioSeconds: f64,
    realTimeFactor: f64,
};

/// read every line from stdin into a list
pub fn read_stdin_pids(allocator: std.mem.Allocator) ![]i64 {
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

    const output = try read_stdin_pids(allocator);
    _ = output;
}

pub const Output = struct {
    write_stdout: bool = false,
    output: []const u8 = "output.wav",
};

pub fn synth_text(
    allocator: Allocator,
    model_path: [:0]const u8,
    text: [:0]const u8,
    config: synth.Config,
    write_to: Output,
) !void {
    const onnx_instance = try synth.load(allocator, model_path);

    var res = try cfg.parse_config_file(allocator, model_path);
    defer res.deinit();

    var output = try phoneme.Phonemize(allocator, text, .{ .voice = "en", .mode = .IPA_MODE });
    defer output.deinit();

    const lines = try output.toSlice();

    // var file: std.fs.File = undefined;
    const sample_rate: usize = 22050;
    const num_channels: usize = 1;
    // var encoder = undefined;
    var file = try std.fs.cwd().createFile(write_to.output, .{});
    var encoder = try wav.encoder(i16, file.writer(), file.seekableStream(), sample_rate, num_channels);

    if (!write_to.write_stdout) {
    }

    for (lines) |value| {
        const phoneme_ids = try pid.phonemes_to_ids(allocator, value, .{}, res);
        defer allocator.free(phoneme_ids);

        const audio = try synth.infer(allocator, onnx_instance, phoneme_ids, config);
        defer allocator.free(audio);

        if (write_to.write_stdout) {
            try write_audio_stdout(audio);
        } else {
            // Write out samples as 16-bit PCM int.
            try encoder.write(i16, audio);
        }
    }

    if (!write_to.write_stdout) {
        try encoder.finalize();
        file.close();
    }
}

pub fn synth_file(
    allocator: Allocator,
    model_pathh: [:0]const u8,
    file_path: []const u8,
    config: synth.Config,
) !void {
    const onnx_instance = try synth.load(allocator, model_pathh);

    const file = try std.fs.cwd().openFile(file_path);
    var buf: [1024 * 2]u8 = undefined;

    while (try file.readAll(&buf) > 0) |n| {
        const text = buf[0..n];

        var output = try phoneme.Phonemize(allocator, text, .{ .voice = "en", .mode = .IPA_MODE });
        defer output.deinit();

        const lines = try output.toSlice();

        for (lines) |value| {
            const phoneme_ids = try pid.phonemes_to_ids(allocator, value, .{});
            defer allocator.free(phoneme_ids);

            const audio = try synth.infer(allocator, onnx_instance, phoneme_ids, config);
            defer allocator.free(audio);
        }
    }
}

pub fn synth_writer(
    allocator: Allocator,
    model_path: [:0]const u8,
    text: [:0]const u8,
    writer: anytype,
    config: synth.Config,
) !void {
    const onnx_instance = try synth.load(allocator, model_path);

    var res = try cfg.parse_config_file(allocator, model_path);
    defer res.deinit();

    var output = try phoneme.Phonemize(allocator, text, .{ .voice = "en", .mode = .IPA_MODE });
    defer output.deinit();

    const lines = try output.toSlice();

    for (lines) |value| {
        const phoneme_ids = try pid.phonemes_to_ids(allocator, value, .{}, res);
        defer allocator.free(phoneme_ids);

        const audio = try synth.infer(allocator, onnx_instance, phoneme_ids, config);
        defer allocator.free(audio);

        try write_audio_writer(audio, writer);
    }
}

pub fn write_audio_stdout(audio: []i16) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    for (audio) |value| {
        try stdout.writeInt(i16, value, .little);
    }

    try bw.flush();
}

pub fn write_audio_writer(audio: []i16, writer: anytype) !void {
    for (audio) |value| {
        try writer.writeInt(i16, value, .little);
    }
}
