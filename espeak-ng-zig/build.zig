const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce Position Independent Code");

    // const use_mbrola = b.option(bool, "mbrola", "Use mbrola");
    // const use_libsonic = b.option(bool, "sonic", "Use libsonic");
    // const use_libpcaudio = b.option(bool, "pcaudio", "Use PCAUDIO");

    const lib = b.addStaticLibrary(.{
        .name = "espeak-ng",
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .pic = pic,
    });

    const espeak = b.dependency("espeak-ng", .{
        .target = target,
        .optimize = optimize,
    });

    const config_h = b.addConfigHeader(.{
        .include_path = "config.h",
    }, .{
        .PACKAGE = "espeak-ng",
        .PACKAGE_BUGREPORT = "https://github.com/espeak-ng/espeak-ng/issues",
        .PACKAGE_NAME = "eSpeak NG",
        .PACKAGE_STRING = "eSpeak NG 1.52.0",
        .PACKAGE_TARNAME = "espeak-ng",
        .PACKAGE_URL = "https://github.com/espeak-ng/espeak-ng",
        .PACKAGE_VERSION = "1.52.0",
        .STDC_HEADERS = 1,
        .VERSION = "1.52.0",
        .LT_OBJDIR = ".libs/",
        .HAVE_DLFCN_H = 1,
        .HAVE_DUP2 = 1,
        .HAVE_ENDIAN_H = 1,
        .HAVE_FCNTL_H = 1,
        .HAVE_FORK = 1,
        .HAVE_GETOPT_H = 1,
        .HAVE_GETOPT_LONG = 1,
        .HAVE_GETTIMEOFDAY = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_LOCALE_H = 1,
        .HAVE_MALLOC = 1,
        .HAVE_MEMCHR = 1,
        .HAVE_MEMMOVE = 1,
        .HAVE_MEMSET = 1,
        .HAVE_MKDIR = 1,
        .HAVE_MKSTEMP = 1,
        .HAVE_PCAUDIOLIB_AUDIO_H = 0,
        .HAVE_SONIC_H = 0,
        .HAVE_LIBSONIC = 0,
        // .#undef = HAVE_POW */,
        .HAVE_REALLOC = 1,
        .HAVE_SETLOCALE = 1,
        // .#undef = HAVE_SQRT */,
        .HAVE_STDBOOL_H = 1,
        .HAVE_STDDEF_H = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_STDIO_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRCHR = 1,
        .HAVE_STRCOLL = 1,
        .HAVE_STRDUP = 1,
        .HAVE_STRERROR = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_STRRCHR = 1,
        .HAVE_STRSTR = 1,
        // .#undef = HAVE_SYS_ENDIAN_H */,
        .HAVE_SYS_STAT_H = 1,
        .HAVE_SYS_TIME_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_UNISTD_H = 1,
        // .#undef = HAVE_VALGRIND_MEMCHECK_H */,
        .HAVE_VFORK = 1,
        // .#undef = HAVE_VFORK_H */,
        .HAVE_WCHAR_H = 1,
        .HAVE_WCTYPE_H = 1,
        .HAVE_WORKING_FORK = 1,
        .HAVE_WORKING_VFORK = 1,
    });

    // lib.addConfigHeader(config_h);
    const _config_h = b.addConfigHeader(.{
        .include_path = "config.h",
    }, .{
        .PACKAGE = "espeak-ng",
        .PACKAGE_BUGREPORT = "https://github.com/espeak-ng/espeak-ng/issues",
        .PACKAGE_NAME = "eSpeak NG",
        .PACKAGE_STRING = "eSpeak NG 1.52.0",
        .PACKAGE_TARNAME = "espeak-ng",
        .PACKAGE_URL = "https://github.com/espeak-ng/espeak-ng",
        .PACKAGE_VERSION = "1.52.0",
        .STDC_HEADERS = 1,
        .VERSION = "1.52.0",
        .LT_OBJDIR = ".libs/",
    });

    _ = _config_h;
    lib.addConfigHeader(config_h);

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    flags.append("-DUSE_ASYNC=0") catch unreachable;
    flags.append("-DBUILD_SHARED_LIBS=1") catch unreachable;
    flags.append("-DUSE_MBROLA=0") catch unreachable;
    flags.append("-DUSE_LIBSONIC=0") catch unreachable;
    flags.append("-DUSE_LIBPCAUDIO=0") catch unreachable;
    flags.append("-DUSE_KLATT=0") catch unreachable;
    flags.append("-DUSE_SPEECHPLAYER=0") catch unreachable;
    flags.append("-DCMAKE_C_FLAGS=-D_FILE_OFFSET_BITS=64") catch unreachable;
    flags.append("-DEXTRA_cmn=1") catch unreachable;
    flags.append("-DEXTRA_ru=1") catch unreachable;
    // fixes error when passing Zig strings to espeak_SetVoiceByName etc...
    // TODO: find out why (maybe its the strncpy0 fn)
    flags.append("-fno-sanitize=undefined") catch unreachable;

    lib.addCSourceFiles(.{
        .root = espeak.path(""),
        .files = &c_files,
        .flags = flags.items,
    });

    lib.addIncludePath(espeak.path("include"));
    lib.addIncludePath(espeak.path("src/libespeak-ng"));
    lib.addIncludePath(espeak.path("src/ucd-tools/src/include"));
    lib.addIncludePath(espeak.path("src/speechPlayer/src"));

    // lib.linkSystemLibrary("pthread");
    lib.linkLibC();

    switch (optimize) {
        .Debug, .ReleaseSafe => lib.bundle_compiler_rt = true,
        .ReleaseFast, .ReleaseSmall => {},
    }

    b.installArtifact(lib);

    lib.installHeadersDirectory(espeak.path("src/include/espeak-ng"), "", .{});
}

const c_files = [_][]const u8{
    "src/ucd-tools/src/case.c",
    "src/ucd-tools/src/categories.c",
    "src/ucd-tools/src/ctype.c",
    "src/ucd-tools/src/proplist.c",
    "src/ucd-tools/src/scripts.c",
    "src/ucd-tools/src/tostring.c",
    "src/libespeak-ng/common.c",
    "src/libespeak-ng/compiledata.c",
    "src/libespeak-ng/compiledict.c",
    "src/libespeak-ng/dictionary.c",
    "src/libespeak-ng/encoding.c",
    "src/libespeak-ng/error.c",
    "src/libespeak-ng/espeak_api.c",
    "src/libespeak-ng/ieee80.c",
    "src/libespeak-ng/intonation.c",
    "src/libespeak-ng/langopts.c",
    "src/libespeak-ng/mnemonics.c",
    "src/libespeak-ng/numbers.c",
    "src/libespeak-ng/readclause.c",
    "src/libespeak-ng/phoneme.c",
    "src/libespeak-ng/phonemelist.c",
    "src/libespeak-ng/setlengths.c",
    "src/libespeak-ng/soundicon.c",
    "src/libespeak-ng/spect.c",
    "src/libespeak-ng/speech.c",
    "src/libespeak-ng/ssml.c",
    "src/libespeak-ng/synthdata.c",
    "src/libespeak-ng/synthesize.c",
    "src/libespeak-ng/translate.c",
    "src/libespeak-ng/translateword.c",
    "src/libespeak-ng/tr_languages.c",
    "src/libespeak-ng/voices.c",
    "src/libespeak-ng/wavegen.c",
};

const async_c = [_][]const u8{
    "src/ucd-tools/src/case.c",
    "src/ucd-tools/src/categories.c",
    "src/ucd-tools/src/ctype.c",
    "src/ucd-tools/src/proplist.c",
    "src/ucd-tools/src/scripts.c",
    "src/ucd-tools/src/tostring.c",
    "src/ucd-tools/tests/printcdata.c",
    "src/ucd-tools/tests/printucddata.c",
};

const ucd = [_][]const u8{
    "src/ucd-tools/src/case.c",
    "src/ucd-tools/src/categories.c",
    "src/ucd-tools/src/ctype.c",
    "src/ucd-tools/src/proplist.c",
    "src/ucd-tools/src/scripts.c",
    "src/ucd-tools/src/tostring.c",
    "src/ucd-tools/tests/printcdata.c",
    "src/ucd-tools/tests/printucddata.c",
};

const if_mbrola_files = [_][]const u8{
    "src/libespeak-ng/mbrowrap.c",
    "src/libespeak-ng/synth_mbrola.c",
    "src/libespeak-ng/compilembrola.c",
};

const include_headers = [_][]const u8{
    "src/include/espeak-ng/encoding.h",
    "src/include/espeak-ng/espeak_ng.h",
    "src/include/espeak-ng/speak_lib",
};

const no_install_headers = [_][]const u8{
    "src/libespeak-ng/common.h",
    "src/libespeak-ng/compiledict.h",
    "src/libespeak-ng/dictionary.h",
    "src/libespeak-ng/error.h",
    "src/libespeak-ng/espeak_command.h",
    "src/libespeak-ng/event.h",
    "src/libespeak-ng/fifo.h",
    "src/libespeak-ng/ieee80.h",
    "src/libespeak-ng/intonation.h",
    "src/libespeak-ng/klatt.h",
    "src/libespeak-ng/langopts.h",
    "src/libespeak-ng/mbrola.h",
    "src/libespeak-ng/mbrowrap.h",
    "src/libespeak-ng/mnemonics.h",
    "src/libespeak-ng/numbers.h",
    "src/libespeak-ng/phoneme.h",
    "src/libespeak-ng/phonemelist.h",
    "src/libespeak-ng/readclause.h",
    "src/libespeak-ng/setlengths.h",
    "src/libespeak-ng/sintab.h",
    "src/libespeak-ng/soundicon.h",
    "src/libespeak-ng/spect.h",
    "src/libespeak-ng/speech.h",
    "src/libespeak-ng/sPlayer.h",
    "src/libespeak-ng/ssml.h",
    "src/libespeak-ng/synthdata.h",
    "src/libespeak-ng/synthesize.h",
    "src/libespeak-ng/translate.h",
    "src/libespeak-ng/translateword.h",
    "src/libespeak-ng/voice.h",
    "src/libespeak-ng/wavegen.h",
    "src/speechPlayer/include/speechPlayer.h",
    "src/speechPlayer/src/frame.h",
    "src/speechPlayer/src/sample.h",
    "src/speechPlayer/src/speechPlayer.h",
    "src/speechPlayer/src/speechWaveGenerator.h",
    "src/speechPlayer/src/utils.h",
    "src/speechPlayer/src/waveGenerator.h",
    "src/ucd-tools/src/include/ucd/ucd.h",
};
