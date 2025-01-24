const onnx = @import("onnxruntime");
const std = @import("std");
const log = @import("std").log;
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const MAX_WAV_VALUE: f32 = 32767.0;

const input_names = [_][:0]const u8{ "input", "input_lengths", "scales", "sid" };
const output_names = [_][:0]const u8{"output"};

pub const Config = struct {
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
};

pub fn load_model(
    allocator: Allocator,
    model_path: [:0]const u8,
    phoneme_ids: []i64,
    synthesisConfig: Config,
) !void {
    _ = synthesisConfig; // autofix

    const onnx_opts = onnx.OnnxInstanceOpts{
        .log_id = "\x1b[32m[PIPER ZIG]\x1b[0m",
        .log_level = .warning,
        .model_path = model_path,
        .num_threads = 1,
        .input_names = &.{ "input", "input_lengths", "scales", "sid" },
        .output_names = &.{"output"},
    };

    var onnx_instance = try onnx.OnnxInstance.init(allocator, onnx_opts);
    try onnx_instance.initMemoryInfo("Cpu", .arena, 0, .default);
    defer onnx_instance.deinit();

    const phoneme_id_shape: []const i64 = &.{ 1, @intCast(phoneme_ids.len) };
    const pidshape_tensor = try onnx_instance.createTensorWithDataAsOrtValue(
        i64,
        phoneme_ids,
        phoneme_id_shape,
        .i64,
    );

    var phoneme_ids_len: [1]i64 = undefined;
    @memset(&phoneme_ids_len, 0);
    phoneme_ids_len[0] = @intCast(phoneme_ids.len);

    const phoneme_id_len_shape: []const i64 = &.{@intCast(phoneme_ids_len.len)};
    const pidlen_tensor = try onnx_instance.createTensorWithDataAsOrtValue(
        i64,
        &phoneme_ids_len,
        // phoneme_id_shape,
        phoneme_id_len_shape,
        .i64,
    );

    var scales: [3]f32 = .{
        // synthesisConfig.noiseScale,
        // synthesisConfig.lengthScale,
        // synthesisConfig.noiseW,
        0.667,
        1.0,
        0.8,
    };

    const scales_shape: []const i64 = &.{scales.len};
    const scale_tensor = try onnx_instance.createTensorWithDataAsOrtValue(
        f32,
        &scales,
        scales_shape,
        .f32,
    );

    // not necessary to have this really
    // var speaker_id: [1]i64 = undefined;
    // speaker_id[0] = 0;

    // if speaker ID is in config add it
    // if (1) {
    //     var speaker_id: [1]i64 = .{0};
    //     const speaker_id_shape = [_]i64{speaker_id.len};
    //
    //     const speaker_tensor = try onnx_instance.createTensorWithDataAsOrtValue(
    //         i64,
    //         &speaker_id,
    //         &speaker_id_shape,
    //         .i64,
    //     );
    // }

    const ort_inputs = try allocator.dupe(*onnx.c_api.OrtValue, &.{
        pidshape_tensor,
        pidlen_tensor,
        scale_tensor,
        // speaker_tensor,
    });

    // time inference
    const start = try std.time.Instant.now();

    var output_tensor: ?*onnx.c_api.OrtValue = null;

    const status = onnx_instance.ort_api.Run.?(
        onnx_instance.session,
        onnx_instance.run_opts,
        onnx_instance.input_names.ptr,
        ort_inputs.ptr,
        ort_inputs.len,
        onnx_instance.output_names.ptr,
        onnx_instance.output_names.len,
        &output_tensor,
    );

    try onnx.Error(onnx_instance.ort_api, status);

    const end = try std.time.Instant.now();
    const timed = end.since(start);
    std.debug.print("time: {d}\n", .{timed});

    if (try onnx_instance.isTensor(output_tensor)) {
        std.debug.print("is tensor\n", .{});
        if (output_tensor == null) {
            std.debug.print("tensor is null\n", .{});
        }
    }

    // const elem_count = try onnx.getTensorElementCount(allocator, onnx_instance.ort_api, output_tensor);
    const elem_count: usize = @intCast(try onnx.getTensorShapeCount(allocator, onnx_instance.ort_api, output_tensor));

    std.debug.print("elem count outer: {d}\n", .{elem_count});
    var buf: []f32 = try allocator.alloc(f32, elem_count);
    // defer allocator.free(buf);

    try onnx.Error(
        onnx_instance.ort_api,
        onnx_instance.ort_api.GetTensorMutableData.?(output_tensor, @ptrCast(&buf)),
    );

    var max_audio_value: f32 = 0.01;
    const newbuf = buf[0..@intCast(elem_count)];

    for (newbuf, 0..) |_, i| {
        const value = @abs(newbuf[i]);
        if (value > max_audio_value) {
            max_audio_value = value;
        }
    }
    std.debug.print("max audio value: {e}\n", .{max_audio_value});

    var audio: []i16 = try allocator.alloc(i16, elem_count);
    defer allocator.free(audio);

    const min: f32 = std.math.minInt(i16);
    const max: f32 = std.math.maxInt(i16);
    const audio_scale: f32 = (MAX_WAV_VALUE / @as(f32, @max(0.01, max_audio_value)));

    for (elem_count, 0..) |_, i| {
        const val: f32 = (buf[i] * audio_scale);

        const audio_value: i16 = @intFromFloat(std.math.clamp(
            val,
            min,
            max,
        ));

        audio[i] = audio_value;
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    for (audio) |value| {
        try stdout.writeInt(i16, value, .little);
    }

    try bw.flush();
}

// uint64 u = 20090520145024798;
// unsigned long w = u % 1000000000;
// unsigned millisec = w % 1000;
// w /= 1000;
// unsigned sec = w % 100;
// w /= 100;
// unsigned min = w % 100;
// unsigned hour = w / 100;
// unsigned long v = w / 1000000000;
// unsigned day = v % 100;
// v /= 100;
// unsigned month = v % 100;
// unsigned year = v / 100;

// var is_tensor: c_int = undefined;
// const _status = onnx_instance.ort_api.IsTensor.?(audio_output, &is_tensor);
// try onnx.Error(onnx_instance.ort_api, _status);
//
// if (onnx_instance.ort_api.SessionGetModelMetadata) |func| {
//     var meta: ?*onnx.c_api.OrtModelMetadata = std.mem.zeroes(?*onnx.c_api.OrtModelMetadata);
//     const status = func(onnx_instance.session, &meta);
//     try onnx.Error(onnx_instance.ort_api, status);
// }
