const std = @import("std");

extern fn runMetalExample() c_int;

pub fn main() !void {
    const result = runMetalExample();
    if (result != 0) {
        std.log.err("Metal example exited with code {d}", .{result});
        return error.MetalExampleFailed;
    }
}
