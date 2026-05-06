# zig-impeller

A Zig binding for the Impeller rendering engine on desktop (Linux, macOS, Windows). Exposes Impeller's C API while staying independent of any windowing system.

## Status

- `impeller.h` is largely wrapped in Zig.
- Linux, macOS, and Windows GLFW examples are in place.
- `FragmentProgram` wrappers exist but are not validated end-to-end yet (no reproducible `.frag` to `.iplr` flow).

## Build and run

If `-Dexample` is omitted, the build defaults to the host platform.

```bash
zig build     -Dexample=<linux|macos|windows>
zig build run -Dexample=<linux|macos|windows>
```

## Examples

| Platform | Backend | Source |
| --- | --- | --- |
| Linux   | Vulkan | [examples/linux/linux_glfw.zig](examples/linux/linux_glfw.zig)       |
| macOS   | Metal  | [examples/macos/macos_glfw.zig](examples/macos/macos_glfw.zig)       |
| Windows | Vulkan | [examples/windows/windows_glfw.zig](examples/windows/windows_glfw.zig) |

## Platform notes

### Linux

GLFW + Vulkan. Select the GLFW backend with `-Dglfw=<auto|x11|wayland>` (default `auto`):

```bash
zig build run -Dexample=linux -Dglfw=x11
```

If the window renders white or geometry is missing, try `-Dglfw=x11` first. On KDE Plasma, x11 / XWayland works while wayland sometimes shows a blank window. The same issue reproduces in the upstream Impeller C sample, so it is not necessarily a binding bug.

### macOS

GLFW + Metal. A small Objective-C glue file ([macos_glfw_metal.m](examples/macos/macos_glfw_metal.m)) attaches a `CAMetalLayer` to the GLFW-owned `NSView` and hands `CAMetalDrawable` instances back to Zig each frame.

### Windows

GLFW + Vulkan; the drawing pipeline mirrors the Linux example because Impeller only ships a Vulkan backend on Windows. Both `x86_64` and `aarch64` are supported (`vendor/impeller/lib/windows/{x64,arm64}`).

`impeller.dll` is copied next to the executable automatically. A working `vulkan-1.dll` must still be available system-wide; install a recent GPU driver or the Vulkan SDK if context creation fails.
