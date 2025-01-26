const onnx = @import("onnxruntime");
const std = @import("std");
const time = @import("logger/time.zig");
const log = @import("std").log;
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const MAX_WAV_VALUE: f32 = 32767.0;

const input_names = [_][:0]const u8{ "input", "input_lengths", "scales", "sid" };
const output_names = [_][:0]const u8{"output"};

pub const Config = struct {
    // VITS inference settings
    noiseScale: f32 = 0.667,
    lengthScale: f32 = 1.0,
    noiseW: f32 = 0.8,
    // Audio settings
    sampleRate: u16 = 22050,
    sampleWidth: u8 = 2, // 16-bit
    channels: u8 = 1, // mono
    // Speaker id from 0 to numSpeakers - 1
    // std::optional<SpeakerId> speakerId;

    // Extra silence
    sentenceSilenceSeconds: f32 = 0.2,
};

pub fn load(
    allocator: Allocator,
    model_path: [:0]const u8,
) !*onnx.OnnxInstance {
    const onnx_opts = onnx.OnnxInstanceOpts{
        .log_id = "\x1b[32m[PIPER ZIG]\x1b[0m",
        .log_level = .warning,
        .model_path = model_path,
        .num_threads = 3,
        .input_names = &.{ "input", "input_lengths", "scales", "sid" },
        .output_names = &.{"output"},
    };

    var onnx_instance = try onnx.OnnxInstance.init(allocator, onnx_opts);
    try onnx_instance.initMemoryInfo("Cpu", .arena, 0, .default);
    return onnx_instance;
}

/// must free the audio
pub fn infer(
    allocator: Allocator,
    onnx_instance: *onnx.OnnxInstance,
    phoneme_ids: []i64,
    config: Config,
) ![]i16 {
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
        phoneme_id_len_shape,
        .i64,
    );

    var scales: [3]f32 = .{
        config.noiseScale,
        config.lengthScale,
        config.noiseW,
    };

    const scales_shape: []const i64 = &.{scales.len};
    const scale_tensor = try onnx_instance.createTensorWithDataAsOrtValue(
        f32,
        &scales,
        scales_shape,
        .f32,
    );

    const ort_inputs = try allocator.dupe(*onnx.c_api.OrtValue, &.{
        pidshape_tensor,
        pidlen_tensor,
        scale_tensor,
    });

    // time inference
    // const start = try std.time.Instant.now();
    const start = time.DateTime.now();

    var output_tensor: ?*onnx.c_api.OrtValue = null;

    const outputs = try allocator.dupe(?*onnx.c_api.OrtValue, &.{output_tensor});

    // put this here so its called in deinit()
    // TODO: fix this and make a better API to handle one ort value
    onnx_instance.setManagedInputsOutputs(ort_inputs, outputs);

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

    if (!try onnx_instance.isTensor(output_tensor)) {
        if (output_tensor == null) {
            return error.NullTensor;
        }
        return error.NotATensor;
    }

    const audio_count: usize = @intCast(try onnx.getTensorShapeCount(allocator, onnx_instance.ort_api, output_tensor));
    log.debug("audio count outer: {d}", .{audio_count});

    // const end = try std.time.Instant.now();
    const end = time.DateTime.now();
    const timed = end.since(start).ms;

    var real_time: f32 = 0.0;
    const audio_seconds: f32 = @as(f32, @floatFromInt(audio_count)) / @as(f32, @floatFromInt(config.sampleRate));

    if (audio_seconds > 0) {
        real_time = @as(f32, @floatFromInt(timed)) / audio_seconds;
    }

    // std.fmt.format
    log.info("real-time factor {d:.1}", .{real_time});
    log.info("synthesized {d:.1} seconds(s) of audio in {d} milliseconds", .{ audio_seconds, timed });

    // GetTensorMutableData takes a pointer as an argument and changes it
    // to point at an internal buffer with the output data, we then cast
    // that to a Zig slice
    var audio_ptr: [*]f32 = undefined;

    // retrieve the output audio (a buffer of floats)
    try onnx.Error(
        onnx_instance.ort_api,
        // onnx_instance.ort_api.GetTensorMutableData.?(output_tensor, @ptrCast(&audio_buffer)),
        onnx_instance.ort_api.GetTensorMutableData.?(output_tensor, @ptrCast(&audio_ptr)),
    );

    const audio_buffer: []f32 = audio_ptr[0..audio_count];

    // retrieve max audio value
    var max_audio_value: f32 = 0.01;

    for (audio_buffer, 0..) |_, i| {
        const value = @abs(audio_buffer[i]);
        if (value > max_audio_value) {
            max_audio_value = value;
        }
    }

    log.debug("max audio value: {d:.1}", .{max_audio_value});

    // cast the output data to signed 16-bit Little Endian audio
    var audio: []i16 = try allocator.alloc(i16, audio_count);

    const min: f32 = std.math.minInt(i16);
    const max: f32 = std.math.maxInt(i16);
    const audio_scale: f32 = (MAX_WAV_VALUE / @as(f32, @max(0.01, max_audio_value)));

    for (audio_count, 0..) |_, i| {
        const val: f32 = (audio_buffer[i] * audio_scale);

        const audio_value: i16 = @intFromFloat(std.math.clamp(
            val,
            min,
            max,
        ));

        audio[i] = audio_value;
    }

    return audio;
}

pub fn load_model(
    allocator: Allocator,
    model_path: [:0]const u8,
    phoneme_ids: []i64,
    config: Config,
) !void {
    const onnx_opts = onnx.OnnxInstanceOpts{
        .log_id = "\x1b[32m[PIPER ZIG]\x1b[0m",
        .log_level = .warning,
        .model_path = model_path,
        .num_threads = 3,
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
        phoneme_id_len_shape,
        .i64,
    );

    var scales: [3]f32 = .{
        config.noiseScale,
        config.lengthScale,
        config.noiseW,
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
    // if (1 == 2) {
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
    });

    // time inference
    // const start = try std.time.Instant.now();
    const start = time.DateTime.now();

    var output_tensor: ?*onnx.c_api.OrtValue = null;

    const outputs = try allocator.dupe(?*onnx.c_api.OrtValue, &.{output_tensor});

    // put this here so its called in deinit()
    // TODO: fix this and make a better API to handle one ort value
    onnx_instance.setManagedInputsOutputs(ort_inputs, outputs);

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

    if (!try onnx_instance.isTensor(output_tensor)) {
        if (output_tensor == null) {
            return error.NullTensor;
        }
        return error.NotATensor;
    }

    const audio_count: usize = @intCast(try onnx.getTensorShapeCount(allocator, onnx_instance.ort_api, output_tensor));
    log.debug("audio count outer: {d}", .{audio_count});

    // const end = try std.time.Instant.now();
    const end = time.DateTime.now();
    const timed = end.since(start).ms;

    var real_time: f32 = 0.0;
    const audio_seconds: f32 = @as(f32, @floatFromInt(audio_count)) / @as(f32, @floatFromInt(config.sampleRate));

    if (audio_seconds > 0) {
        real_time = @as(f32, @floatFromInt(timed)) / audio_seconds;
    }

    // std.fmt.format
    log.info("real-time factor {d:.1}", .{real_time});
    log.info("synthesized {d:.1} seconds(s) of audio in {d} milliseconds", .{ audio_seconds, timed });

    // GetTensorMutableData takes a pointer as an argument and changes it
    // to point at an internal buffer with the output data, we then cast
    // that to a Zig slice
    var audio_ptr: [*]f32 = undefined;

    // retrieve the output audio (a buffer of floats)
    try onnx.Error(
        onnx_instance.ort_api,
        // onnx_instance.ort_api.GetTensorMutableData.?(output_tensor, @ptrCast(&audio_buffer)),
        onnx_instance.ort_api.GetTensorMutableData.?(output_tensor, @ptrCast(&audio_ptr)),
    );

    const audio_buffer: []f32 = audio_ptr[0..audio_count];

    // retrieve max audio value
    var max_audio_value: f32 = 0.01;

    for (audio_buffer, 0..) |_, i| {
        const value = @abs(audio_buffer[i]);
        if (value > max_audio_value) {
            max_audio_value = value;
        }
    }

    log.debug("max audio value: {d:.1}", .{max_audio_value});

    // cast the output data to signed 16-bit Little Endian audio
    var audio: []i16 = try allocator.alloc(i16, audio_count);
    defer allocator.free(audio);

    const min: f32 = std.math.minInt(i16);
    const max: f32 = std.math.maxInt(i16);
    const audio_scale: f32 = (MAX_WAV_VALUE / @as(f32, @max(0.01, max_audio_value)));

    for (audio_count, 0..) |_, i| {
        const val: f32 = (audio_buffer[i] * audio_scale);

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
