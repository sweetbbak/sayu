const std = @import("std");
const strings = @import("strings.zig");

const Allocator = std.mem.Allocator;
const span = std.mem.span;

const c = @cImport({
    @cInclude("speak_lib.h");
});

pub const SpeakerId = u64;
pub const PhonemeId = i64;
pub const Phoneme = u32;

pub const PhoneticMode = enum(c_int) {
    ASCII_MODE = 0x00,
    PHONETIC_MODE = 0x01,
    IPA_MODE = 0x02,
};

const CLAUSE_INTONATION_FULL_STOP = 0x00000000;
const CLAUSE_INTONATION_COMMA = 0x00001000;
const CLAUSE_INTONATION_QUESTION = 0x00002000;
const CLAUSE_INTONATION_EXCLAMATION = 0x00003000;

const CLAUSE_TYPE_CLAUSE = 0x00040000;
const CLAUSE_TYPE_SENTENCE = 0x00080000;

const CLAUSE_PERIOD = (40 | CLAUSE_INTONATION_FULL_STOP | CLAUSE_TYPE_SENTENCE);
const CLAUSE_COMMA = (20 | CLAUSE_INTONATION_COMMA | CLAUSE_TYPE_CLAUSE);
const CLAUSE_QUESTION = (40 | CLAUSE_INTONATION_QUESTION | CLAUSE_TYPE_SENTENCE);
const CLAUSE_EXCLAMATION = (45 | CLAUSE_INTONATION_EXCLAMATION | CLAUSE_TYPE_SENTENCE);
const CLAUSE_COLON = (30 | CLAUSE_INTONATION_FULL_STOP | CLAUSE_TYPE_CLAUSE);
const CLAUSE_SEMICOLON = (30 | CLAUSE_INTONATION_COMMA | CLAUSE_TYPE_CLAUSE);

pub const PhonemeConfig = struct {
    voice: []const u8 = "en-us",
    period: []const u8 = ".",
    comma: []const u8 = ",",
    question: []const u8 = "?",
    exclamation: []const u8 = "!",
    colon: []const u8 = ":",
    semicolon: []const u8 = ";",
    space: []const u8 = " ",
};

pub const TextCasing = enum(c_int) {
    CASING_IGNORE,
    CASING_LOWER,
    CASING_UPPER,
    CASING_FOLD,
};

pub const MAX_PHONEMES = 256;

/// espeak config
pub const Config = struct {
    mode: PhoneticMode = .IPA_MODE,
    data_path: [:0]const u8 = "/usr/share/espeak-ng-data",
    voice: [:0]const u8 = "en",
    phoneme_config: PhonemeConfig = .{},
};

pub const Result = struct {
    allocator: Allocator,
    list: std.ArrayList([]const u8),
    sb: strings.StringBuilder,

    const Self = @This();

    pub fn init(allocator: Allocator, buf: []u8) Self {
        return Self{
            .allocator = allocator,
            .list = std.ArrayList([]const u8).init(allocator),
            .sb = strings.StringBuilder.init(buf),
        };
    }

    pub fn toSlice(self: *Self) ![][]const u8 {
        return self.list.items;
    }

    pub fn deinit(self: *Self) void {
        for (self.list.items) |value| {
            self.allocator.free(value);
        }

        self.list.deinit();
    }
};

// pub fn Phonemize(allocator: Allocator, input: [:0]const u8, cfg: Config) ![][]const u8 {
pub fn Phonemize(allocator: Allocator, input: [:0]const u8, cfg: Config) !Result {
    const buflen = 500;
    const options = 0;

    const exit = c.espeak_Initialize(
        c.AUDIO_OUTPUT_SYNCH_PLAYBACK,
        buflen,
        @ptrCast(cfg.data_path),
        options,
    );
    if (exit < 0) return error.Init;

    defer {
        _ = c.espeak_Terminate();
    }

    if (c.espeak_SetVoiceByName(cfg.voice) != 0) {
        return error.SetVoice;
    }

    var terminator: c_int = 0x00;
    var str: ?*const anyopaque = @ptrCast(input);

    // var list = std.ArrayList([]const u8).init(allocator);
    // defer list.deinit();

    var buf: [1024 * 2]u8 = undefined;
    // var sb = strings.StringBuilder.init(&buf);

    var result: Result = Result.init(allocator, &buf);
    // _ = &result;

    // var list = result.list;
    // var sb = result.sb;

    while (str != null) {
        const cstr = c.espeak_TextToPhonemesWithTerminator(
            &str,
            c.espeakCHARS_AUTO,
            @intFromEnum(cfg.mode),
            @ptrCast(&terminator),
        );

        result.sb.append(span(cstr));

        const punctuation = terminator & 0x000FFFFF;
        switch (punctuation) {
            CLAUSE_PERIOD => {
                result.sb.append(cfg.phoneme_config.period);
            },
            CLAUSE_QUESTION => {
                result.sb.append(cfg.phoneme_config.question);
            },
            CLAUSE_EXCLAMATION => {
                result.sb.append(cfg.phoneme_config.exclamation);
            },
            CLAUSE_COMMA => {
                result.sb.append(cfg.phoneme_config.comma);
                result.sb.append(cfg.phoneme_config.space);
            },
            CLAUSE_COLON => {
                result.sb.append(cfg.phoneme_config.colon);
                result.sb.append(cfg.phoneme_config.space);
            },
            CLAUSE_SEMICOLON => {
                result.sb.append(cfg.phoneme_config.semicolon);
                result.sb.append(cfg.phoneme_config.space);
            },
            else => {},
        }

        if ((terminator & CLAUSE_TYPE_SENTENCE) == CLAUSE_TYPE_SENTENCE) {
            const sentence = try result.sb.toOwnedSlice(allocator);
            std.debug.print("full sentence: '{s}'\n", .{sentence});
            try result.list.append(sentence);
            result.sb.reset();
            @memset(result.sb.buffer, 0);
        }
    }

    // return try list.toOwnedSlice();
    return result;
}
