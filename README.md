# zig-impeller

A Zig binding for the Impeller rendering engine on desktop platforms. It wraps the standalone `impeller.h` C API and keeps the API close to the original while exposing a more Zig-friendly surface.

<p align="left">
  <img src="https://github.com/user-attachments/assets/938615ee-55aa-4a76-a106-c778151ede53" width="400">
</p>

## What it provides

- Zig wrappers for most of the standalone Impeller C API
- Desktop backends for:
  - Linux + Vulkan
  - macOS + Metal
  - Windows + Vulkan
- Real GLFW examples for all three platforms
- Small Zig helpers around colors, rectangles, matrices, mappings, textures, paths, display lists, and typography

## Install

Add the package with `zig fetch`:

```bash
zig fetch --save git+https://github.com/KercyDing/zig-impeller#main
```

Then add zig-impeller as a dependency and import its module in your `build.zig`:

```zig
const impeller_dep = b.dependency("zig_impeller", .{
    .target = target,
    .optimize = optimize,
});

const exe = b.addExecutable(.{
    .name = "demo",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "impeller", .module = impeller_dep.module("impeller") },
        },
    }),
});
```

Then use it in Zig code with:

```zig
const impeller = @import("impeller");
```

## Minimal demo

Smallest Linux + GLFW + Vulkan example that actually draws a rectangle.

This snippet needs a GLFW binding such as [glfw_zig](https://github.com/tiawl/glfw.zig) because it imports `glfw_c`. That dependency belongs to the application using zig-impeller.

```zig
const impeller = @import("impeller");
const glfw = @import("glfw_c");

pub fn main() !void {
    // Uncomment on some Wayland/KDE setups if the window is blank.
    // glfw.glfwInitHint(glfw.GLFW_PLATFORM, glfw.GLFW_PLATFORM_X11);
    _ = glfw.glfwInit();
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    const window = glfw.glfwCreateWindow(800, 600, "impeller demo", null, null).?;
    defer glfw.glfwDestroyWindow(window);

    var context = try impeller.Context.initVulkan(.{
        .user_data = null,
        .proc_address_callback = VulkanProcResolver.resolve,
        .enable_vulkan_validation = true,
    });
    defer context.deinit();

    const info = context.vulkanInfo().?;
    var vk_surface: glfw.VkSurfaceKHR = null;
    _ = glfw.glfwCreateWindowSurface(@ptrCast(info.vk_instance), window, null, &vk_surface);

    var swapchain = try impeller.VulkanSwapchain.init(context, @ptrCast(vk_surface));
    defer swapchain.deinit();

    var builder = try impeller.DisplayListBuilder.init(null);
    defer builder.deinit();

    var paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(1.0, 1.0, 1.0, 1.0));
    builder.drawPaint(paint);
    paint.setColor(impeller.srgb(0.2, 0.4, 1.0, 1.0));
    builder.drawRect(impeller.rect(120.0, 100.0, 240.0, 160.0), paint);

    var list = try builder.build();
    defer list.deinit();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();
        var surface = swapchain.acquireNextSurface() catch continue;
        defer surface.deinit();
        try surface.draw(list);
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
```

For complete platform-specific setups, see the examples below.

## Build and run examples

```bash
zig build test
zig build examples -Dplatform=<linux|macos|windows>
```

The default `zig build` only builds the library artifact. The `examples` step pulls the GLFW example dependency and builds the selected platform example.

## Examples

| Platform | Backend | Source |
| --- | --- | --- |
| Linux   | Vulkan | [examples/linux/linux_glfw.zig](examples/linux/linux_glfw.zig) |
| macOS   | Metal  | [examples/macos/macos_glfw.zig](examples/macos/macos_glfw.zig) |
| Windows | Vulkan | [examples/windows/windows_glfw.zig](examples/windows/windows_glfw.zig) |

Shared drawing code lives in [examples/common/draw.zig](examples/common/draw.zig), while each platform keeps its own window/system integration entry point.

## Platform notes

### Linux

The Linux example uses GLFW + Vulkan. Select the GLFW backend with `-Dglfw=<auto|x11|wayland>`:

```bash
zig build examples -Dplatform=linux -Dglfw=x11
```

If the window renders white or geometry is missing, try `-Dglfw=x11` first. On KDE Plasma, x11 / XWayland works while wayland may show a blank window. The same issue reproduces in the upstream Impeller C sample, so it is not necessarily a binding bug.

### macOS

The macOS example uses GLFW + Metal. A small Objective-C bridge in [examples/macos/macos_glfw_metal.m](examples/macos/macos_glfw_metal.m) attaches a `CAMetalLayer` to the GLFW-owned `NSView` and returns `CAMetalDrawable` objects to Zig each frame.

### Windows

The Windows example uses GLFW + Vulkan. Impeller currently ships the Windows backend through Vulkan.

`impeller.dll` is copied next to the executable automatically. A working `vulkan-1.dll` must still be available system-wide through a recent GPU driver or Vulkan SDK installation.

## Status

- `impeller.h` is largely wrapped in Zig
- Linux, macOS, and Windows GLFW examples are in place
- Unit test step is available through `zig build test`
- `FragmentProgram` wrappers exist, but they are not validated end-to-end yet because there is no reproducible `.frag` -> `.iplr` workflow in this repository
