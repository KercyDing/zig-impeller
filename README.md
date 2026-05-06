# zig-impeller

Zig bindings for Impeller's standalone `impeller.h` API.

<p align="left">
  <img src="https://github.com/user-attachments/assets/938615ee-55aa-4a76-a106-c778151ede53" width="400">
</p>

## Features

- Linux + Vulkan
- macOS + Metal
- Windows + Vulkan
- GLFW examples for all supported platforms
- Zig wrappers for contexts, surfaces, paints, paths, textures, display lists, typography, and basic geometry

## Install

```bash
zig fetch --save git+https://github.com/KercyDing/zig-impeller#main
```

Add the dependency in `build.zig`:

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

Then import it:

```zig
const impeller = @import("impeller");
```

## Minimal drawing

Core drawing code:

```zig
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

try surface.draw(list);
try surface.present();
```

For a complete runnable app, see the platform examples below.

## Examples

```bash
zig build test
zig build examples
zig build examples -Dplatform=<linux|macos|windows>
```

`zig build` builds the library. `zig build examples` builds and runs the host-platform example by default.

| Platform | Backend | Source |
| --- | --- | --- |
| Linux | Vulkan | [examples/linux/linux_glfw.zig](examples/linux/linux_glfw.zig) |
| macOS | Metal | [examples/macos/macos_glfw.zig](examples/macos/macos_glfw.zig) |
| Windows | Vulkan | [examples/windows/windows_glfw.zig](examples/windows/windows_glfw.zig) |

Shared drawing code is in [examples/common/draw.zig](examples/common/draw.zig).

## Platform notes

### Linux

Choose a GLFW backend with `-Dglfw=<auto|x11|wayland>`:

```bash
zig build examples -Dplatform=linux -Dglfw=x11
```

If the window is blank on KDE/Wayland, try X11.

### macOS

The macOS example uses GLFW + Metal, with a small Objective-C bridge for `CAMetalLayer`.

### Windows

The Windows example uses GLFW + Vulkan. A working `vulkan-1.dll` must be available from the GPU driver or Vulkan SDK.

## Status

- Most of `impeller.h` is wrapped
- Desktop GLFW examples are available
- `zig build test` runs unit tests
- `FragmentProgram` is wrapped, but shader packaging is not documented here yet
