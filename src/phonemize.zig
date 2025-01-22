const std = @import("std");
const id = @import("phoneme_id.zig");
const map = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const span = std.mem.span;
const uni = std.unicode;

const c = @cImport({
    @cInclude("speak_lib.h");
});

const ASCII_MODE = 0x0;
const PHONETIC_MODE = 0x1;
const IPA_MODE = 0x2;

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

/// phoneme map
pub const PhonemeMap = map(Phoneme, []Phoneme);

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

pub const Config = struct {
    mode: PhoneticMode = .IPA_MODE,
    data_path: [:0]const u8 = "/usr/share/espeak-ng-data",
    // voice: [:0]const u8 = "en",
    voice: [*:0]const u8 = "en",
};

// static std::map<std::string, PhonemeIdMap> DEFAULT_ALPHABET = {
pub const MAX_PHONEMES = 256;

pub fn Phonemize(allocator: Allocator, input: [:0]const u8, cfg: Config) ![][]const u8 {
    const buflen = 500;
    // const buflen = 22050;
    const options = 0;

    const exit = c.espeak_Initialize(c.AUDIO_OUTPUT_SYNCH_PLAYBACK, buflen, @ptrCast(cfg.data_path), options);
    if (exit != c.EE_OK) {
        switch (exit) {
            c.EE_INTERNAL_ERROR => return error.EE_INTERNAL_ERROR,
            c.EE_BUFFER_FULL => return error.EE_BUFFER_FULL,
            c.EE_NOT_FOUND => return error.EE_NOT_FOUND,
            else => {
                // std.debug.print("exit init: {d}\n", .{exit});
                // err 22050?
                // return error.IDK;
            },
        }
    }

    defer {
        _ = c.espeak_Terminate();
    }

    // var voice: [*]const u8 = @ptrCast("en-us");
    // if (c.espeak_SetVoiceByName(@ptrCast(&voice)) < 0) {

    var voice: c.espeak_VOICE = std.mem.zeroes(c.espeak_VOICE);
    const lang: [*:0]const u8 = "en";
    voice.languages = lang;
    voice.name = "US";
    voice.variant = 2;
    voice.gender = 2;
    _ = c.espeak_SetVoiceByProperties(&voice);

    // only works on ReleaseFast ???
    // if (c.espeak_SetVoiceByName(cfg.voice) < 0) {
    // if (c.espeak_SetVoiceByName(lang) < 0) {
    // return error.SetVoice;
    // }

    var terminator: c_int = 0x00;

    // very easy to mess this up if the pointer is not mutable
    var str: ?*const anyopaque = @ptrCast(&input);

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    while (str != null) {
        const cstr = c.espeak_TextToPhonemesWithTerminator(
            &str,
            c.espeakCHARS_AUTO,
            @intFromEnum(cfg.mode),
            @ptrCast(&terminator),
        );

        const owned_str = try allocator.dupeZ(u8, span(cstr));

        try list.append(owned_str);

        for (owned_str) |value| {
            const point = id.GetPhonemeId(value);
            std.debug.print("{d}\n", .{point});
        }

        const punctuation = terminator & 0x000FFFFF;

        switch (punctuation) {
            CLAUSE_PERIOD => {
                try list.append(".");
            },
            CLAUSE_QUESTION => {
                try list.append("?");
            },
            CLAUSE_EXCLAMATION => {
                try list.append("!");
            },
            CLAUSE_COMMA => {
                try list.append(",");
                try list.append(" ");
            },
            CLAUSE_COLON => {
                try list.append(":");
                try list.append(" ");
            },
            CLAUSE_SEMICOLON => {
                try list.append(";");
                try list.append(" ");
            },
            else => {
                if ((terminator & CLAUSE_TYPE_SENTENCE) == CLAUSE_TYPE_SENTENCE) {
                    // End of sentence
                    // sentencePhonemes = nullptr;
                    try list.append("$");
                }
            },
        }
    }

    return try list.toOwnedSlice();
}

pub fn Phonemize2(allocator: Allocator, input: [:0]const u8, cfg: Config) ![][]const u8 {
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

    // var voice: [*]const u8 = @ptrCast("en-us");
    // if (c.espeak_SetVoiceByName(@ptrCast(&voice)) < 0) {
    if (c.espeak_SetVoiceByName(cfg.voice) < 0) {
        return error.SetVoice;
    }

    var terminator: c_int = 0x00;
    var str: ?*const anyopaque = @ptrCast(input);

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    while (str != null) {
        const cstr = c.espeak_TextToPhonemesWithTerminator(
            &str,
            c.espeakCHARS_AUTO,
            0x1,
            @ptrCast(&terminator),
        );

        std.debug.print("{s}\n", .{span(cstr)});
        const owned_str = try allocator.dupeZ(u8, span(cstr));
        try list.append(owned_str);

        const punctuation = terminator & 0x000FFFFF;
        // std.debug.print("punc type: {d}\n", .{punctuation});

        switch (punctuation) {
            CLAUSE_PERIOD => {},
            CLAUSE_QUESTION => {},
            CLAUSE_EXCLAMATION => {},
            CLAUSE_COMMA => {},
            CLAUSE_COLON => {},
            CLAUSE_SEMICOLON => {},
            else => {
                if ((terminator & CLAUSE_TYPE_SENTENCE) == CLAUSE_TYPE_SENTENCE) {
                    // End of sentence
                    // sentencePhonemes = nullptr;
                }
            },
        }
    }

    return try list.toOwnedSlice();
}

pub fn Phonemize_example() !void {
    const buflen = 500;
    const options = 0;
    // this has to be updated to come from the lib
    const data = "/usr/share/espeak-ng-data";

    const exit = c.espeak_Initialize(
        c.AUDIO_OUTPUT_SYNCH_PLAYBACK,
        buflen,
        @ptrCast(data),
        options,
    );
    if (exit < 0) return error.Init;

    defer {
        _ = c.espeak_Terminate();
    }

    const voice: [:0]const u8 = "en-us";
    if (c.espeak_SetVoiceByName(@ptrCast(voice)) < 0) {
        return error.SetVoice;
    }

    // var terminator: c_int = 0x00;
    var _str: ?*const anyopaque = "hello, world! how are you doing? I am fine I guess...";

    while (_str != null) {
        // const _cstr = c.espeak_TextToPhonemesWithTerminator(
        //     &_str,
        //     c.espeakCHARS_AUTO,
        //     0x1,
        //     @ptrCast(&terminator),
        // );
        const _cstr = c.espeak_TextToPhonemes(
            &_str,
            c.espeakCHARS_AUTO,
            0x1,
        );

        const new = span(_cstr);
        const new2 = std.mem.sliceTo(_cstr, 0);
        std.debug.print("{*} {s}\n", .{ _cstr, span(_cstr) });
        std.debug.print("{*} {s}\n", .{ new, new });
        std.debug.print("{*} {s}\n", .{ new2, new2 });
    }
}
