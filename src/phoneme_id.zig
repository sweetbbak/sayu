const std = @import("std");
const phoneme = @import("phonemize.zig");
const config = @import("config.zig");
const piper = @import("piper.zig");
const pc = piper.PiperConfig;
const PhonemeId = @import("phonemize.zig").PhonemeId;
const Phoneme = @import("phonemize.zig").Phoneme;
const Allocator = std.mem.Allocator;

pub const PhonemeIdConfig = struct {
    idPad: PhonemeId = 0, // padding (optionally interspersed)
    idBos: PhonemeId = 1, // beginning of sentence
    idEos: PhonemeId = 2, // end of sentence

    pad: Phoneme = '_',
    bos: Phoneme = '^',
    eos: Phoneme = '$',

    interspersePad: bool = true,
    addBos: bool = true,
    addEos: bool = true,
};

// pub fn GetPhonemeId(codepoint: u32) phoneme.PhonemeId {
pub inline fn GetPhonemeId(codepoint: u32) !PhonemeId {
    switch (codepoint) {
        '_' => return 0,
        '^' => return 1,
        '$' => return 2,
        ' ' => return 3,
        '!' => return 4,
        '\'' => return 5,
        '(' => return 6,
        ')' => return 7,
        ',' => return 8,
        '-' => return 9,
        '.' => return 10,
        ':' => return 11,
        ';' => return 12,
        '?' => return 13,
        'a' => return 14,
        'b' => return 15,
        'c' => return 16,
        'd' => return 17,
        'e' => return 18,
        'f' => return 19,
        'h' => return 20,
        'i' => return 21,
        'j' => return 22,
        'k' => return 23,
        'l' => return 24,
        'm' => return 25,
        'n' => return 26,
        'o' => return 27,
        'p' => return 28,
        'q' => return 29,
        'r' => return 30,
        's' => return 31,
        't' => return 32,
        'u' => return 33,
        'v' => return 34,
        'w' => return 35,
        'x' => return 36,
        'y' => return 37,
        'z' => return 38,
        'æ' => return 39,
        'ç' => return 40,
        'ð' => return 41,
        'ø' => return 42,
        'ħ' => return 43,
        'ŋ' => return 44,
        'œ' => return 45,
        'ǀ' => return 46,
        'ǁ' => return 47,
        'ǂ' => return 48,
        'ǃ' => return 49,
        'ɐ' => return 50,
        'ɑ' => return 51,
        'ɒ' => return 52,
        'ɓ' => return 53,
        'ɔ' => return 54,
        'ɕ' => return 55,
        'ɖ' => return 56,
        'ɗ' => return 57,
        'ɘ' => return 58,
        'ə' => return 59,
        'ɚ' => return 60,
        'ɛ' => return 61,
        'ɜ' => return 62,
        'ɞ' => return 63,
        'ɟ' => return 64,
        'ɠ' => return 65,
        'ɡ' => return 66,
        'ɢ' => return 67,
        'ɣ' => return 68,
        'ɤ' => return 69,
        'ɥ' => return 70,
        'ɦ' => return 71,
        'ɧ' => return 72,
        'ɨ' => return 73,
        'ɪ' => return 74,
        'ɫ' => return 75,
        'ɬ' => return 76,
        'ɭ' => return 77,
        'ɮ' => return 78,
        'ɯ' => return 79,
        'ɰ' => return 80,
        'ɱ' => return 81,
        'ɲ' => return 82,
        'ɳ' => return 83,
        'ɴ' => return 84,
        'ɵ' => return 85,
        'ɶ' => return 86,
        'ɸ' => return 87,
        'ɹ' => return 88,
        'ɺ' => return 89,
        'ɻ' => return 90,
        'ɽ' => return 91,
        'ɾ' => return 92,
        'ʀ' => return 93,
        'ʁ' => return 94,
        'ʂ' => return 95,
        'ʃ' => return 96,
        'ʄ' => return 97,
        'ʈ' => return 98,
        'ʉ' => return 99,
        'ʊ' => return 100,
        'ʋ' => return 101,
        'ʌ' => return 102,
        'ʍ' => return 103,
        'ʎ' => return 104,
        'ʏ' => return 105,
        'ʐ' => return 106,
        'ʑ' => return 107,
        'ʒ' => return 108,
        'ʔ' => return 109,
        'ʕ' => return 110,
        'ʘ' => return 111,
        'ʙ' => return 112,
        'ʛ' => return 113,
        'ʜ' => return 114,
        'ʝ' => return 115,
        'ʟ' => return 116,
        'ʡ' => return 117,
        'ʢ' => return 118,
        'ʲ' => return 119,
        'ˈ' => return 120,
        'ˌ' => return 121,
        'ː' => return 122,
        'ˑ' => return 123,
        '˞' => return 124,
        'β' => return 125,
        'θ' => return 126,
        'χ' => return 127,
        'ᵻ' => return 128,
        'ⱱ' => return 129,
        // // tones
        '0' => return 130,
        '1' => return 131,
        '2' => return 132,
        '3' => return 133,
        '4' => return 134,
        '5' => return 135,
        '6' => return 136,
        '7' => return 137,
        '8' => return 138,
        '9' => return 139,
        '\u{0327}' => return 140, // combining cedilla
        // '̧' => 140,  // combining cedilla
        '\u{0303}' => return 141, // combining tilde
        '\u{032a}' => return 142, // combining bridge below
        '\u{032f}' => return 143, // combining inverted breve below
        '\u{0329}' => return 144, // combining vertical line below
        'ʰ' => return 145,
        'ˤ' => return 146,
        'ε' => return 147,
        '↓' => return 148,
        // {U'#', {149}},  // Icelanic
        '\"' => return 150, // Russian
        '↑' => return 151,
        // Basque
        '\u{033a}' => return 152,
        '\u{033b}' => return 153,
        // Luxembourgish
        'g' => return 154,
        'ʦ' => return 155,
        'X' => return 156,
        // Czech
        // '\u{031}' => 157,
        '\u{030a}' => return 158,
        else => return error.NoMatch,
    }
}

pub fn to_phoneme_ids(allocator: Allocator, sentence: [][]const u8) ![]PhonemeId {
    var list = std.ArrayList(PhonemeId).init(allocator);
    defer list.deinit();

    for (sentence) |line| {
        var uni = try std.unicode.Utf8View.init(line);
        var iterator = uni.iterator();

        while (iterator.nextCodepoint()) |codepoint| {
            const id = GetPhonemeId(codepoint);
            try list.append(id);
        }
    }

    return list.toOwnedSlice();
}

pub fn sentence_to_ids(allocator: Allocator, line: []const u8) ![]PhonemeId {
    var list = std.ArrayList(PhonemeId).init(allocator);
    defer list.deinit();

    var uni = try std.unicode.Utf8View.init(line);
    var iterator = uni.iterator();

    while (iterator.nextCodepoint()) |codepoint| {
        const id = GetPhonemeId(codepoint);
        try list.append(id);
    }

    return list.toOwnedSlice();
}

pub fn phonemes_to_ids(allocator: Allocator, line: []const u8, cfg: PhonemeIdConfig) ![]PhonemeId {
    var list = std.ArrayList(PhonemeId).init(allocator);
    defer list.deinit();

    var uni = try std.unicode.Utf8View.init(line);
    var iterator = uni.iterator();

    var result = try config.parse_config(allocator, config.piper_json);
    defer result.deinit();

    const map = result.config.phoneme_id_map.map;

    if (cfg.addBos) {
        try list.append(cfg.idBos);
    }

    while (iterator.nextCodepointSlice()) |codepoint| {
        if (cfg.interspersePad) {
            try list.append(cfg.idPad);
        }

        const ids = map.get(codepoint);

        if (ids) |_ids| {
            for (_ids) |id| {
                try list.append(id);
            }
        }
    }

    if (cfg.interspersePad) {
        try list.append(cfg.idPad);
    }

    if (cfg.addEos) {
        try list.append(cfg.idEos);
    }

    return list.toOwnedSlice();
}

test "test phonemes to ids" {
    const u = try std.unicode.utf8Decode("\u{030a}");
    const _id = GetPhonemeId(u);
    try std.testing.expectEqual(158, _id);

    const allocator = std.testing.allocator;

    // "How are you doing"
    const input_ids = &[_]i64{ 1, 0, 20, 0, 121, 0, 14, 0, 100, 0, 3, 0, 51, 0, 122, 0, 88, 0, 3, 0, 22, 0, 33, 0, 122, 0, 3, 0, 17, 0, 120, 0, 33, 0, 122, 0, 74, 0, 44, 0, 13, 0, 2 };
    const phonemes = "hˌaʊ ɑːɹ juː dˈuːɪŋ?";

    const output = try phonemes_to_ids(allocator, phonemes, .{});
    defer allocator.free(output);

    try std.testing.expect(output.len == input_ids.len);

    std.debug.print("\n\n+----mine-+-piper----+\n", .{});
    for (output, 0..) |value, i| {
        const expected = input_ids[i];
        std.debug.print("{d:0>2}: {d: <5} {d}\n", .{ i, value, expected });
        try std.testing.expectEqual(expected, value);
    }
}
