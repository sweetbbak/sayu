const std = @import("std");
const piper = @import("piper.zig");
const phoneme = @import("phonemize.zig");
const synth = @import("synth.zig");
const pid = @import("phoneme_id.zig");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const http = std.http;
const net = std.net;
const json = std.json;
const logFn = @import("logger/log.zig").myLogFn;
const log = std.log;

pub fn serve(ip: []const u8, port: u16) !void {
    // const address = try std.net.Address.parseIp("127.0.0.1", 8080);
    const address = try std.net.Address.parseIp(ip, port);
    var net_server = try address.listen(.{ .reuse_address = true });
    defer net_server.deinit();
    std.log.info("listening at {s}:{}/", .{ ip, address.getPort() });

    while (true) {
        var connection = try net_server.accept();
        const thread = try std.Thread.spawn(.{}, handler, .{&connection});
        try thread.setName("sayu-server");
        thread.detach();
    }
}

fn handler(connection: *std.net.Server.Connection) !void {
    defer connection.stream.close();
    var read_buffer: [1024]u8 = undefined;
    var server = std.http.Server.init(connection.*, &read_buffer);
    var request = try server.receiveHead();
    std.debug.print("{s}\t{s}\n", .{ @tagName(request.head.method), request.head.target });
    try request.respond("Hello world!", .{});
}

pub fn serve_main(server_addr: []const u8, server_port: u16) !void {
    const addr = net.Address.parseIp4(server_addr, server_port) catch |err| {
        std.debug.print("An error occurred while resolving the IP address: {}\n", .{err});
        return;
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var server = try addr.listen(.{});
    start_server(allocator, &server);
}

fn start_server(allocator: Allocator, server: *net.Server) void {
    while (true) {
        var connection = server.accept() catch |err| {
            std.debug.print("Connection to client interrupted: {}\n", .{err});
            continue;
        };
        defer connection.stream.close();

        var read_buffer: [1024]u8 = undefined;
        var http_server = http.Server.init(connection, &read_buffer);

        var request = http_server.receiveHead() catch |err| {
            std.debug.print("Could not read head: {}\n", .{err});
            continue;
        };

        handle_request(allocator, &request, &http_server.connection.stream) catch |err| {
            std.debug.print("Could not handle request: {}", .{err});
            continue;
        };
    }
}

const model_path: [:0]const u8 = "/home/sweet/ssd/pipertts/ivona_tts/amy.onnx";

const Req = struct {
    text: []const u8,
};

fn handle_request(
    allocator: Allocator,
    request: *http.Server.Request,
    stream: *std.net.Stream,
) !void {
    log.info("Handling request for {s}", .{request.head.target});
    const reader = try request.reader();

    const body = try reader.readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    const parsed = try json.parseFromSlice(Req, allocator, body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const writer = stream.writer().any();
    // const text = "hello world";
    const rate = 0.5;

    // try piper.synth_writer(allocator, model_path, @ptrCast(text), writer, .{ .lengthScale = rate });
    try piper.synth_writer(allocator, model_path, @ptrCast(parsed.value.text), writer, .{ .lengthScale = rate });

    // try request.respond("Hello http!\n", .{});
    // const it = request.iterateHeaders();
    // while (it.next()) |item| {
    // }
}
