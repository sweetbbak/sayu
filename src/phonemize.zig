const std = @import("std");
const strings = @import("strings.zig");

const map = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const span = std.mem.span;
const uni = std.unicode;

const c = @cImport({
    @cInclude("speak_lib.h");
});

const ASCII_MODE = @as(c_int, 0x0);
const PHONETIC_MODE = @as(c_int, 0x1);
const IPA_MODE = @as(c_int, 0x2);

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
    period: u8 = '.',
    comma: u8 = ',',
    question: u8 = '?',
    exclamation: u8 = '!',
    colon: u8 = ':',
    semicolon: u8 = ';',
    space: u8 = ' ',
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
};

pub const Result = struct {
    phonemes: [][]const u8,
    ids: []i64,
};

pub fn Phonemize(allocator: Allocator, input: [:0]const u8, cfg: Config) ![][]const u8 {
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

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    var buf: [1024 * 2]u8 = undefined;
    var sb = strings.StringBuilder.init(&buf);

    while (str != null) {
        const cstr = c.espeak_TextToPhonemesWithTerminator(
            &str,
            c.espeakCHARS_AUTO,
            @intFromEnum(cfg.mode),
            @ptrCast(&terminator),
        );

        sb.append(span(cstr));

        const punctuation = terminator & 0x000FFFFF;
        switch (punctuation) {
            CLAUSE_PERIOD => {
                sb.append(".");
            },
            CLAUSE_QUESTION => {
                sb.append("?");
            },
            CLAUSE_EXCLAMATION => {
                sb.append("!");
            },
            CLAUSE_COMMA => {
                sb.append(",");
            },
            CLAUSE_COLON => {
                sb.append(":");
            },
            CLAUSE_SEMICOLON => {
                sb.append(";");
            },
            else => {},
        }

        if ((terminator & CLAUSE_TYPE_SENTENCE) == CLAUSE_TYPE_SENTENCE) {
            const sentence = try sb.toOwnedSlice(allocator);
            try list.append(sentence);
            sb.reset();
        }
    }

    return try list.toOwnedSlice();
}
