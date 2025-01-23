const std = @import("std");
const id = @import("phoneme_id.zig");

pub const SpeakerId = u64;
pub const PhonemeId = i64;

pub const eSpeakConfig = struct {
    voice: []const u8 = "en-us",
};

pub const PiperConfig = struct {
    eSpeakDataPath: []const u8,
    useESpeak: bool = true,
};

pub const PhonemeType = enum { eSpeakPhonemes, TextPhonemes };

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

pub const ModelSession = struct {
    // session: onnx.c_api.OrtSession,
    // env: onnx.c_api.OrtEnv,
    // allocator: onnx.c_api.struct_OrtApi.GetAllocatorWithDefaultOptions(),
    // options: onnx.OnnxInstanceOpts,
    //   Ort::AllocatorWithDefaultOptions allocator;
    //   Ort::SessionOptions options;
    //   Ort::Env env;
    //
    //   ModelSession() : onnx(nullptr){};
};

pub const SynthesisResult = struct {
    inferSeconds: f64,
    audioSeconds: f64,
    realTimeFactor: f64,
};

pub const Voice = struct {
    // json configRoot;
    phonemizeConfig: PhonemizeConfig,
    synthesisConfig: SynthesisConfig,
    modelConfig: ModelConfig,
    session: ModelSession,
};

pub const MAX_WAV_VALUE: f32 = 32767.0;
