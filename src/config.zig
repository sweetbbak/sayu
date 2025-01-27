const std = @import("std");
const json = std.json;

const expect = std.testing.expect;
const eql = std.mem.eql;

const Allocator = std.mem.Allocator;
const ArrayHashMap = std.ArrayHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const StringArrayHashMap = std.StringArrayHashMap;

const Place = struct { lat: f32, long: f32 };

const PiperConfig = struct {
    audio: struct {
        sample_rate: usize,
    },

    // espeak: [][]const u8,
    espeak: struct {
        voice: []const u8,
    },

    inference: struct {
        noise_scale: f32,
        length_scale: f32,
        noise_w: f32,
    },

    phoneme_type: []const u8,
    phoneme_map: struct {},

    phoneme_id_map: json.ArrayHashMap([]i64),

    num_symbols: usize,
    num_speakers: usize,
    speaker_id_map: struct {},
    piper_version: []const u8,
};

/// contains the parsed json and the Piper config, call deinit to release resources.
pub const Result = struct {
    json: json.Parsed(PiperConfig),
    config: PiperConfig,

    pub fn deinit(self: *@This()) void {
        self.json.deinit();
    }
};

pub fn parse_config(allocator: Allocator, contents: []const u8) !Result {
    const parsed = try json.parseFromSlice(PiperConfig, allocator, contents, .{ .ignore_unknown_fields = true });
    return .{ .json = parsed, .config = parsed.value };
}

/// looks for a file like: model.onnx -> model.onnx.json and parses it
pub fn parse_config_file(allocator: Allocator, model_path: []const u8) !Result {
    const new_path = try std.fmt.allocPrint(allocator, "{s}.json", .{model_path});
    defer allocator.free(new_path);

    const file = try std.fs.cwd().openFile(new_path, .{});
    defer file.close();

    std.log.info("opening config: {s}", .{new_path});

    const contents = try file.readToEndAlloc(allocator, 1024 * 10);
    // defer allocator.free(contents);
    return parse_config(allocator, contents);
}

test "piper config" {
    const allocator = std.testing.allocator;
    const contents = piper_json;

    var result = try parse_config(allocator, contents);
    var config = result.config;
    defer result.deinit();

    const x = config.phoneme_id_map.map.get("!") orelse unreachable;
    std.debug.print("get(\"!\") = {any}\n", .{x});
    try expect(x[0] == 4);

    const y = config.phoneme_id_map.map.get("œ") orelse unreachable;
    std.debug.print("get(\"œ\") = {any}\n", .{y});
    try expect(y[0] == 45);

    const z = config.phoneme_id_map.map.get(" ") orelse unreachable;
    std.debug.print("get(\"ɕ\") = {any}\n", .{z});
    try expect(z[0] == 3);

    for (lookups) |char| {
        const item = config.phoneme_id_map.map.get(char) orelse {
            std.debug.print("get(\"{s}\") - lookup failed\n", .{char});
            continue;
        };

        std.debug.print("get(\"{s}\") = {any}\n", .{ char, item });
        try expect(item[0] < 255 and item[0] >= 0);
    }
}

pub const PhonemesMap = std.StaticStringMap(i64).initComptime(.{
    .{ "a", 0 },
});

// And using stringify to turn arbitrary data into a string.
test "json stringify" {
    const x = Place{
        .lat = 51.997664,
        .long = -0.740687,
    };

    var buf: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var string = std.ArrayList(u8).init(fba.allocator());
    try std.json.stringify(x, .{}, string.writer());

    try expect(eql(u8, string.items,
        \\{"lat":5.199766540527344e1,"long":-7.406870126724243e-1}
    ));
}

pub const piper_json =
    \\ {"audio":{"sample_rate":22050},"espeak":{"voice":"en-us"},"inference":{"noise_scale":0.667,"length_scale":1,"noise_w":0.8},"phoneme_type":"espeak","phoneme_map":{},"phoneme_id_map":{" ":[3],"!":[4],"\"":[150],"#":[149],"$":[2],"'":[5],"(":[6],")":[7],",":[8],"-":[9],".":[10],"0":[130],"1":[131],"2":[132],"3":[133],"4":[134],"5":[135],"6":[136],"7":[137],"8":[138],"9":[139],":":[11],";":[12],"?":[13],"X":[156],"^":[1],"_":[0],"a":[14],"b":[15],"c":[16],"d":[17],"e":[18],"f":[19],"g":[154],"h":[20],"i":[21],"j":[22],"k":[23],"l":[24],"m":[25],"n":[26],"o":[27],"p":[28],"q":[29],"r":[30],"s":[31],"t":[32],"u":[33],"v":[34],"w":[35],"x":[36],"y":[37],"z":[38],"æ":[39],"ç":[40],"ð":[41],"ø":[42],"ħ":[43],"ŋ":[44],"œ":[45],"ǀ":[46],"ǁ":[47],"ǂ":[48],"ǃ":[49],"ɐ":[50],"ɑ":[51],"ɒ":[52],"ɓ":[53],"ɔ":[54],"ɕ":[55],"ɖ":[56],"ɗ":[57],"ɘ":[58],"ə":[59],"ɚ":[60],"ɛ":[61],"ɜ":[62],"ɞ":[63],"ɟ":[64],"ɠ":[65],"ɡ":[66],"ɢ":[67],"ɣ":[68],"ɤ":[69],"ɥ":[70],"ɦ":[71],"ɧ":[72],"ɨ":[73],"ɪ":[74],"ɫ":[75],"ɬ":[76],"ɭ":[77],"ɮ":[78],"ɯ":[79],"ɰ":[80],"ɱ":[81],"ɲ":[82],"ɳ":[83],"ɴ":[84],"ɵ":[85],"ɶ":[86],"ɸ":[87],"ɹ":[88],"ɺ":[89],"ɻ":[90],"ɽ":[91],"ɾ":[92],"ʀ":[93],"ʁ":[94],"ʂ":[95],"ʃ":[96],"ʄ":[97],"ʈ":[98],"ʉ":[99],"ʊ":[100],"ʋ":[101],"ʌ":[102],"ʍ":[103],"ʎ":[104],"ʏ":[105],"ʐ":[106],"ʑ":[107],"ʒ":[108],"ʔ":[109],"ʕ":[110],"ʘ":[111],"ʙ":[112],"ʛ":[113],"ʜ":[114],"ʝ":[115],"ʟ":[116],"ʡ":[117],"ʢ":[118],"ʦ":[155],"ʰ":[145],"ʲ":[119],"ˈ":[120],"ˌ":[121],"ː":[122],"ˑ":[123],"˞":[124],"ˤ":[146],"̃":[141],"̧":[140],"̩":[144],"̪":[142],"̯":[143],"̺":[152],"̻":[153],"β":[125],"ε":[147],"θ":[126],"χ":[127],"ᵻ":[128],"↑":[151],"↓":[148],"ⱱ":[129]},"num_symbols":256,"num_speakers":1,"speaker_id_map":{},"piper_version":"1.0.0"}
;

pub const lookups = [_][]const u8{ "!", "\"", "#", "$", "'", "(", ")", ",", "-", ".", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "?", "X", "^", "_", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" };
