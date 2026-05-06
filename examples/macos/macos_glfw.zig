const std = @import("std");
const impeller = @import("impeller");
const draw = @import("common_draw");
const glfw = @import("glfw_c");

extern fn macosGlfwAttachMetalLayer(nsview: ?*anyopaque) ?*anyopaque;
extern fn macosGlfwAcquireNextDrawable(layer: ?*anyopaque, width: f64, height: f64) ?*anyopaque;
extern fn macosGlfwReleaseDrawable(drawable: ?*anyopaque) void;

/// Returns the underlying NSView for a GLFW window. Declared here because
/// `glfw3native.h` pulls Carbon SDK headers that translate-c cannot parse.
extern fn glfwGetCocoaView(window: ?*glfw.GLFWwindow) ?*anyopaque;

const ExampleError = error{
    GlfwInitFailed,
    WindowCreateFailed,
    MetalLayerAttachFailed,
};

pub fn main() !void {
    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);

    if (glfw.glfwInit() != glfw.GLFW_TRUE) {
        return ExampleError.GlfwInitFailed;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    glfw.glfwWindowHint(glfw.GLFW_COCOA_RETINA_FRAMEBUFFER, glfw.GLFW_TRUE);
    const window = glfw.glfwCreateWindow(800, 600, "zig-impeller Metal", null, null) orelse {
        return ExampleError.WindowCreateFailed;
    };
    defer glfw.glfwDestroyWindow(window);

    const ns_view: ?*anyopaque = glfwGetCocoaView(window);
    const metal_layer = macosGlfwAttachMetalLayer(ns_view) orelse return ExampleError.MetalLayerAttachFailed;

    var context = try impeller.Context.initMetal();
    defer context.deinit();

    var scene = try draw.createScene(context, "macOS");
    defer scene.deinit();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();

        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        var fb_width: c_int = 0;
        var fb_height: c_int = 0;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);

        const drawable = macosGlfwAcquireNextDrawable(
            metal_layer,
            @as(f64, @floatFromInt(fb_width)),
            @as(f64, @floatFromInt(fb_height)),
        ) orelse continue;
        defer macosGlfwReleaseDrawable(drawable);

        var surface = try impeller.Surface.wrapMetalDrawable(context, drawable);
        defer surface.deinit();

        try surface.draw(scene.display_list);
        try surface.present();
    }
}

fn glfwErrorCallback(code: c_int, description: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW Error ({d}): {s}\n", .{ code, std.mem.span(description) });
}
