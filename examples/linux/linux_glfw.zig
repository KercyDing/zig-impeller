const std = @import("std");
const build_options = @import("build_options");
const impeller = @import("impeller");
const glfw = @import("glfw_c");

const glfw_platform = build_options.glfw;

const ExampleError = error{
    GlfwInitFailed,
    VulkanUnavailable,
    WindowCreateFailed,
    VulkanInfoUnavailable,
    PresentationUnsupported,
    SurfaceCreateFailed,
};

pub fn main() !void {
    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);
    configureGlfwPlatform();

    if (glfw.glfwInit() != glfw.GLFW_TRUE) {
        return ExampleError.GlfwInitFailed;
    }
    defer glfw.glfwTerminate();

    if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
        return ExampleError.VulkanUnavailable;
    }

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    const window = glfw.glfwCreateWindow(800, 600, "zig-impeller Vulkan", null, null) orelse {
        return ExampleError.WindowCreateFailed;
    };
    defer glfw.glfwDestroyWindow(window);

    var context = try impeller.Context.initVulkan(.{
        .user_data = null,
        .proc_address_callback = VulkanProcResolver.resolve,
        .enable_vulkan_validation = true,
    });
    defer context.deinit();

    const vulkan_info = context.vulkanInfo() orelse return ExampleError.VulkanInfoUnavailable;

    if (glfw.glfwGetPhysicalDevicePresentationSupport(
        @ptrCast(vulkan_info.vk_instance),
        @ptrCast(vulkan_info.vk_physical_device),
        vulkan_info.graphics_queue_family_index,
    ) != glfw.GLFW_TRUE) {
        return ExampleError.PresentationUnsupported;
    }

    var vulkan_surface: glfw.VkSurfaceKHR = null;
    if (glfw.glfwCreateWindowSurface(@ptrCast(vulkan_info.vk_instance), window, null, &vulkan_surface) != 0) {
        return ExampleError.SurfaceCreateFailed;
    }

    var swapchain = try impeller.VulkanSwapchain.init(context, @ptrCast(vulkan_surface));
    defer swapchain.deinit();

    var display_list = try createDisplayList();
    defer display_list.deinit();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();

        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        var surface = swapchain.acquireNextSurface() catch continue;
        defer surface.deinit();

        try surface.draw(display_list);
        try surface.present();
    }
}

fn createDisplayList() !impeller.DisplayList {
    var builder = try impeller.DisplayListBuilder.init(null);
    defer builder.deinit();

    var paint = try impeller.Paint.init();
    defer paint.deinit();

    var blur = impeller.ImageFilter.initBlur(10.0, 10.0, impeller.c.kImpellerTileModeDecal);
    defer if (blur) |*value| value.deinit();

    paint.setColor(impeller.srgb(1.0, 1.0, 1.0, 1.0));
    builder.drawPaint(paint);

    paint.setColor(impeller.srgb(1.0, 0.0, 0.0, 1.0));
    builder.save();
    builder.clipRect(
        impeller.rect(20, 20, 60, 100),
        impeller.c.kImpellerClipOperationIntersect,
    );
    builder.drawRect(impeller.rect(20, 20, 100, 100), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.0, 0.2, 1.0, 1.0));
    builder.save();
    builder.translate(220, 120);
    builder.rotate(45.0);
    builder.drawRect(impeller.rect(-40, -40, 80, 80), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.0, 0.7, 0.2, 1.0));
    builder.save();
    builder.translate(360, 120);
    builder.scale(1.6, 0.6);
    builder.drawRect(impeller.rect(-40, -40, 80, 80), paint);
    builder.restore();

    const layer_base_count = builder.getSaveCount();
    builder.save();
    builder.translate(520, 80);
    const layer_count = builder.getSaveCount();
    builder.saveLayer(
        impeller.rect(-10, -10, 140, 140),
        null,
        if (blur) |value| value else null,
    );

    paint.setColor(impeller.srgb(0.1, 0.1, 0.1, 0.35));
    builder.drawRect(impeller.rect(24, 24, 72, 72), paint);

    paint.setColor(impeller.srgb(1.0, 0.7, 0.0, 1.0));
    builder.drawRect(impeller.rect(0, 0, 72, 72), paint);

    builder.restoreToCount(layer_count);
    builder.restoreToCount(layer_base_count);

    builder.save();
    builder.setTransform(translationMatrix(680.0, 120.0));
    paint.setColor(impeller.srgb(0.6, 0.0, 0.8, 1.0));
    builder.drawRect(impeller.rect(-24, -24, 48, 48), paint);

    const translated_matrix = builder.getTransform();
    builder.transform(scaleMatrix(1.0, 1.8));
    paint.setColor(impeller.srgb(1.0, 0.0, 1.0, 0.45));
    builder.drawRect(impeller.rect(-24, -24, 48, 48), paint);

    builder.setTransform(translated_matrix);
    builder.resetTransform();
    paint.setColor(impeller.srgb(0.0, 0.7, 0.9, 1.0));
    builder.drawRect(impeller.rect(650, 180, 60, 24), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.95, 0.4, 0.1, 1.0));
    builder.drawOval(impeller.rect(40, 220, 90, 60), paint);

    paint.setColor(impeller.srgb(0.45, 0.2, 0.9, 1.0));
    builder.drawRoundedRect(
        impeller.rect(170, 220, 110, 60),
        impeller.uniformRadii(18.0),
        paint,
    );

    paint.setColor(impeller.srgb(0.1, 0.1, 0.1, 1.0));
    builder.drawRoundedRectDifference(
        impeller.rect(320, 214, 124, 72),
        impeller.uniformRadii(22.0),
        impeller.rect(344, 232, 76, 36),
        impeller.uniformRadii(10.0),
        paint,
    );

    return builder.build();
}

fn translationMatrix(x: f32, y: f32) impeller.Matrix {
    return .{
        .m = .{
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            x, y, 0.0, 1.0,
        },
    };
}

fn scaleMatrix(x: f32, y: f32) impeller.Matrix {
    return .{
        .m = .{
            x, 0.0, 0.0, 0.0,
            0.0, y, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        },
    };
}

fn configureGlfwPlatform() void {
    switch (glfw_platform) {
        .auto => {},
        .x11 => glfw.glfwInitHint(glfw.GLFW_PLATFORM, glfw.GLFW_PLATFORM_X11),
        .wayland => glfw.glfwInitHint(glfw.GLFW_PLATFORM, glfw.GLFW_PLATFORM_WAYLAND),
    }
}

const VulkanProcResolver = struct {
    fn resolve(instance: ?*anyopaque, proc_name: [*c]const u8, user_data: ?*anyopaque) callconv(.c) ?*anyopaque {
        _ = user_data;
        return @ptrCast(@constCast(glfw.glfwGetInstanceProcAddress(
            if (instance) |handle| @ptrCast(handle) else null,
            proc_name,
        )));
    }
};

fn glfwErrorCallback(code: c_int, description: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW Error ({d}): {s}\n", .{ code, std.mem.span(description) });
}
