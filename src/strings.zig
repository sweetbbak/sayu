// BSD 3-clause licensed. Copyright Léon van der Kaap 2021
const std = @import("std");
const log = std.log;
const mem = std.mem;

const Allocator = std.mem.Allocator;

pub fn toNullTerminatedPointer(slice: []const u8, allocator_impl: Allocator) ![:0]u8 {
    var result = try allocator_impl.alloc(u8, slice.len + 1);
    for (slice, 0..) |_, i| {
        result[i] = slice[i];
    }
    result[result.len - 1] = 0;
    return result[0 .. result.len - 1 :0];
}

pub fn convertOptionalSentinelString(ptr: [*:0]u8) ?[]u8 {
    if (@intFromPtr(ptr) == 0) {
        return null;
    } else {
        return std.mem.sliceTo(ptr, 0);
    }
}

pub fn substringFromNullTerminatedSlice(str: []const u8) []const u8 {
    const index = indexOf(str, 0);
    if (index != null) {
        return str[0..index.?];
    } else {
        return str;
    }
}

pub fn indexOf(string: []const u8, match: u8) ?usize {
    for (string, 0..) |byte, i| {
        if (byte == match) return i;
    }
    return null;
}

pub fn noneIndexOf(string: []const u8, match: u8) ?usize {
    for (string, 0..) |byte, i| {
        if (byte != match) return i;
    }
    return null;
}

pub fn indexOfStartOnPos(string: []const u8, start: usize, match: u8) ?usize {
    if (start >= string.len) return null;
    var i = start;
    while (i < string.len) : (i += 1) {
        if (string[i] == match) return i;
    }
    return null;
}

pub fn lastIndexOf(string: []const u8, match: u8) ?usize {
    var i = string.len;
    while (i > 0) {
        i -= 1;
        if (string[i] == match) return i;
    }
    return null;
}

pub fn lastNonIndexOf(string: []const u8, match: u8) ?usize {
    var i = string.len;
    while (i > 0) {
        i -= 1;
        if (string[i] != match) return i;
    }
    return null;
}

pub fn joinStrings(input: [][]const u8, output: []u8) void {
    var walking_index: usize = 0;
    var i: usize = 1;
    while (i < input.len - 1) {
        for (input[i]) |byte| {
            output[walking_index] = byte;
            walking_index += 1;
        }
        output[walking_index] = ' ';
        walking_index += 1;
        i += 1;
    }
    for (input[input.len - 1]) |byte| {
        output[walking_index] = byte;
        walking_index += 1;
    }
}

pub fn insertStringAtIndex(dest: []u8, source: []const u8, start: *usize) void {
    std.mem.copyForwards(u8, dest[start.* .. start.* + source.len], source);
    start.* += source.len;
}

pub const StringBuilder = struct {
    buffer: []u8,
    insertion_index: usize,

    const Self = @This();
    pub fn init(buffer: []u8) Self {
        return Self{ .buffer = buffer, .insertion_index = 0 };
    }

    pub fn append(self: *Self, input: []const u8) void {
        insertStringAtIndex(self.buffer, input, &self.insertion_index);
    }

    pub fn appendBufPrint(self: *Self, comptime fmt: []const u8, args: anytype) void {
        const inserted = std.fmt.bufPrint(self.buffer[self.insertion_index..], fmt, args) catch return;
        self.insertion_index += inserted.len;
    }

    pub fn toSlice(self: *Self) []u8 {
        return self.buffer[0..self.insertion_index];
    }

    pub fn toOwnedSlice(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.insertion_index);
        std.mem.copyForwards(u8, result, self.buffer[0..self.insertion_index]);
        return result;
    }

    pub fn reset(self: *Self) void {
        self.insertion_index = 0;
    }

    pub fn resetTo(self: *Self, index: usize) void {
        self.insertion_index = index;
    }
};

const StringConfig = struct {
    initial_size: usize = 1024,
    grow_rate: f32 = 1.5,
};

/// a string that is dynamically sized
pub const String = struct {
    buffer: []u8,
    insertion_index: usize,
    allocator: Allocator,
    grow_rate: f32 = 1.5,

    const Self = @This();

    pub fn init(allocator: Allocator, config: StringConfig) !Self {
        // var buf = try allocator.alloc(u8, config.initial_size);
        return Self{
            // .buffer = &buf,
            .buffer = try allocator.alloc(u8, config.initial_size),
            .insertion_index = 0,
            .grow_rate = config.grow_rate,
            .allocator = allocator,
        };
    }

    fn remaining(self: *Self) usize {
        return self.buffer.len - self.insertion_index;
    }

    fn can_fit(self: *Self, len: usize) usize {
        return self.insertion_index + len;
    }

    pub fn append(self: *Self, input: []const u8) !void {
        if (self.remaining() < input.len) {
            try self.resize(input.len);
        }

        const start = &self.insertion_index;
        std.mem.copyForwards(u8, self.buffer[start.* .. start.* + input.len], input);
        start.* += input.len;
    }

    pub fn resize(self: *Self, must_fit: usize) !void {
        var new_size: usize = @intFromFloat(@as(f32, @floatFromInt(self.buffer.len)) * self.grow_rate);
        const new_buflen = self.remaining() + new_size;

        if (new_buflen < self.insertion_index + must_fit) {
            new_size = size: {
                while (self.remaining() + new_size < self.insertion_index + must_fit) {
                    new_size *= 2;
                }
                break :size new_size * 2;
            };
        }

        self.buffer = try self.allocator.realloc(self.buffer, new_size);
        log.debug("realloc: size {d} - loc {*}", .{ new_size, self.buffer.ptr });
    }

    pub fn appendBufPrint(self: *Self, comptime fmt: []const u8, args: anytype) void {
        const inserted = std.fmt.bufPrint(self.buffer[self.insertion_index..], fmt, args) catch return;
        self.insertion_index += inserted.len;
    }

    pub fn toSlice(self: *Self) []u8 {
        return self.buffer[0..self.insertion_index];
    }

    pub fn toOwnedSlice(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.insertion_index);
        std.mem.copyForwards(u8, result, self.buffer[0..self.insertion_index]);
        return result;
    }

    pub fn reset(self: *Self) void {
        self.insertion_index = 0;
    }

    pub fn resetTo(self: *Self, index: usize) void {
        self.insertion_index = index;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }
};

test "dynamic string buffer" {
    const allocator = std.testing.allocator;
    var string = try String.init(allocator, .{ .initial_size = 10 });
    defer string.deinit();

    try string.append("Hello, ");
    try std.testing.expectEqualStrings(string.toSlice(), "Hello, ");
    std.debug.print("'{s}'\n", .{string.toSlice()});

    try string.append("World! ");
    try std.testing.expectEqualStrings(string.toSlice(), "Hello, World! ");
    std.debug.print("'{s}'\n", .{string.toSlice()});

    try string.append("How are you doing?");
    try std.testing.expectEqualStrings(string.toSlice(), "Hello, World! How are you doing?");
    std.debug.print("'{s}'\n", .{string.toSlice()});

    var string2 = try String.init(allocator, .{ .initial_size = 10 });
    defer string2.deinit();

    try string2.append(@embedFile("strings.zig"));
    std.debug.print("'{s}'\n", .{string.toSlice()});

    const str = "* + HELLO WOLRD HELLOW WORLD HELLLOOOO ERLD UWU UWU UWU COOOOOOOOO * + \n";
    try string2.append(str);

    for (33333) |_| {
        try string2.append(str);
        std.debug.print("'{d}'\n", .{string2.insertion_index});
    }

    std.debug.print("'{s}'\n", .{string2.toSlice()});
}
