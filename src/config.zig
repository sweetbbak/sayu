const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;

const Place = struct { lat: f32, long: f32 };

test "json parse" {
    const test_allocator = std.testing.allocator;

    const parsed = try std.json.parseFromSlice(
        Place,
        test_allocator,
        \\{ "lat": 40.684540, "long": -74.401422 }
    ,
        .{},
    );
    defer parsed.deinit();

    const place = parsed.value;

    try expect(place.lat == 40.684540);
    try expect(place.long == -74.401422);
}

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
