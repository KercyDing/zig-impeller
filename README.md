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

Then add zig-impeller as a dependency and import its modules and artifact in your `build.zig`:

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

This is a minimal example that uses only the Zig wrapper types and helpers:

```zig
const std = @import("std");
const impeller = @import("impeller");

pub fn main() !void {
    try impeller.checkVersion();

    const color = impeller.srgb(0.2, 0.4, 1.0, 1.0);
    const area = impeller.rect(20.0, 30.0, 120.0, 64.0);
    const radii = impeller.uniformRadii(12.0);
    const size = impeller.pixelSize(256, 256);
    const descriptor = impeller.textureDescriptor(
        impeller.pixel_formats.rgba8888,
        size,
        1,
    );

    _ = color;
    _ = area;
    _ = radii;
    _ = descriptor;

    std.debug.print("Impeller runtime version: {d}\n", .{impeller.runtimeVersion()});
}
```

If you want a full rendering setup, see the platform examples below.

## Build and run examples

If `-Dexample` is omitted, the build defaults to the host platform.

```bash
zig build test
zig build -Dexample=<linux|macos|windows>
zig build run -Dexample=<linux|macos|windows>
```

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
zig build run -Dexample=linux -Dglfw=x11
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
