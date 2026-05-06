const std = @import("std");
const impeller = @import("impeller");

test "srgb fields" {
    const color = impeller.srgb(0.1, 0.2, 0.3, 0.4);

    try std.testing.expectEqual(@as(f32, 0.1), color.red);
    try std.testing.expectEqual(@as(f32, 0.2), color.green);
    try std.testing.expectEqual(@as(f32, 0.3), color.blue);
    try std.testing.expectEqual(@as(f32, 0.4), color.alpha);
    try std.testing.expectEqual(@as(impeller.ColorSpace, impeller.color_spaces.srgb), color.color_space);
}

test "rect fields" {
    const value = impeller.rect(1.0, 2.0, 3.0, 4.0);

    try std.testing.expectEqual(@as(f32, 1.0), value.x);
    try std.testing.expectEqual(@as(f32, 2.0), value.y);
    try std.testing.expectEqual(@as(f32, 3.0), value.width);
    try std.testing.expectEqual(@as(f32, 4.0), value.height);
}

test "point fields" {
    const value = impeller.point(5.0, 6.0);

    try std.testing.expectEqual(@as(f32, 5.0), value.x);
    try std.testing.expectEqual(@as(f32, 6.0), value.y);
}

test "radii uniform" {
    const value = impeller.uniformRadii(7.0);
    const corner = impeller.point(7.0, 7.0);

    try std.testing.expectEqual(corner, value.top_left);
    try std.testing.expectEqual(corner, value.bottom_left);
    try std.testing.expectEqual(corner, value.top_right);
    try std.testing.expectEqual(corner, value.bottom_right);
}

test "color matrix" {
    const values = [_]f32{
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
    };

    const value = impeller.colorMatrix(values);

    try std.testing.expectEqual(values, value.m);
}

test "pixel size" {
    const value = impeller.pixelSize(8, 9);

    try std.testing.expectEqual(@as(i32, 8), value.width);
    try std.testing.expectEqual(@as(i32, 9), value.height);
}

test "texture descriptor" {
    const size = impeller.pixelSize(10, 11);
    const value = impeller.textureDescriptor(impeller.pixel_formats.rgba8888, size, 12);

    try std.testing.expectEqual(@as(impeller.PixelFormat, impeller.pixel_formats.rgba8888), value.pixel_format);
    try std.testing.expectEqual(size, value.size);
    try std.testing.expectEqual(@as(u32, 12), value.mip_count);
}

test "mapping borrows bytes" {
    const bytes = "impeller";
    const value = impeller.mapping(bytes);

    try std.testing.expectEqual(bytes.ptr, value.data);
    try std.testing.expectEqual(@as(u64, bytes.len), value.length);
    try std.testing.expectEqual(@as(@TypeOf(value.on_release), null), value.on_release);
}
