const std = @import("std");
const build_options = @import("build_options");
const impeller = @import("impeller");
const glfw = @import("glfw_c");

const c = impeller.c;
const glfw_platform = build_options.glfw;

const ExampleError = error{
    GlfwInitFailed,
    VulkanUnavailable,
    WindowCreateFailed,
    VulkanInfoUnavailable,
    PresentationUnsupported,
    SurfaceCreateFailed,
    DisplayListCreateFailed,
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

    const display_list = createDisplayList() orelse return ExampleError.DisplayListCreateFailed;
    defer c.ImpellerDisplayListRelease(display_list);

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();

        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        var surface = swapchain.acquireNextSurface() catch continue;
        defer surface.deinit();

        _ = c.ImpellerSurfaceDrawDisplayList(surface.handle, display_list);
        _ = c.ImpellerSurfacePresent(surface.handle);
    }
}

fn createDisplayList() ?c.ImpellerDisplayList {
    const builder = c.ImpellerDisplayListBuilderNew(null) orelse return null;
    defer c.ImpellerDisplayListBuilderRelease(builder);

    const paint = c.ImpellerPaintNew() orelse return null;
    defer c.ImpellerPaintRelease(paint);

    var clear_color = c.ImpellerColor{
        .red = 1.0,
        .green = 1.0,
        .blue = 1.0,
        .alpha = 1.0,
        .color_space = c.kImpellerColorSpaceSRGB,
    };
    c.ImpellerPaintSetColor(paint, &clear_color);
    c.ImpellerDisplayListBuilderDrawPaint(builder, paint);

    var box_color = c.ImpellerColor{
        .red = 1.0,
        .green = 0.0,
        .blue = 0.0,
        .alpha = 1.0,
        .color_space = c.kImpellerColorSpaceSRGB,
    };
    c.ImpellerPaintSetColor(paint, &box_color);

    var box_rect = c.ImpellerRect{
        .x = 10,
        .y = 10,
        .width = 100,
        .height = 100,
    };
    c.ImpellerDisplayListBuilderDrawRect(builder, &box_rect, paint);

    return c.ImpellerDisplayListBuilderCreateDisplayListNew(builder);
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
