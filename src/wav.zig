const std = @import("std");
const wav = @import("wav");

pub fn writefile(file_name: []const u8, data: []i16) !void {
    var file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    const sample_rate: usize = 22050;
    const num_channels: usize = 1;

    // Write out samples as 16-bit PCM int.
    var encoder = try wav.encoder(i16, file.writer(), file.seekableStream(), sample_rate, num_channels);
    try encoder.write(i16, data);
    try encoder.finalize(); // Don't forget to finalize after you're done writing.
}

pub fn decode(file_name: []const u8) !void {
    var file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var decoder = try wav.decoder(buf_reader.reader());

    var data: [64]f32 = undefined;
    while (true) {
        // Read samples as f32. Channels are interleaved.
        const samples_read = try decoder.read(f32, &data);

        // < ------ Do something with samples in data. ------ >

        if (samples_read < data.len) {
            break;
        }
    }
}
