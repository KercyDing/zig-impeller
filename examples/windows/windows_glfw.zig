const std = @import("std");
const impeller = @import("impeller");
const draw = @import("common_draw");
const glfw = @import("glfw_c");

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

    if (glfw.glfwInit() != glfw.GLFW_TRUE) {
        return ExampleError.GlfwInitFailed;
    }
    defer glfw.glfwTerminate();

    if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
        return ExampleError.VulkanUnavailable;
    }

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    const window = glfw.glfwCreateWindow(800, 600, "zig-impeller Windows", null, null) orelse {
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

    var scene = try draw.createScene(context, "Windows");
    defer scene.deinit();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();

        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        var surface = swapchain.acquireNextSurface() catch continue;
        defer surface.deinit();

        try surface.draw(scene.display_list);
        try surface.present();
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
