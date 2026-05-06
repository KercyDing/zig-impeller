# zig-impeller

A Zig binding for the Impeller rendering engine on desktop platforms.

It exposes Impeller's C API to Zig while staying independent from any specific windowing system.

## Status

- Most of `impeller.h` is already wrapped in Zig.
- The Linux and macOS example paths are in place.
- `FragmentProgram` wrappers exist, but they have not been validated end-to-end yet because this repository does not currently provide a reproducible `.frag` to `.iplr` build flow.

## Build and run

If `-Dexample` is omitted, the build defaults to the current host platform.

```bash
zig build -Dexample=linux
zig build -Dexample=macos
zig build -Dexample=windows

zig build run -Dexample=linux
zig build run -Dexample=macos
zig build run -Dexample=windows
```

## Examples

- Linux GLFW + Vulkan: [linux_glfw.zig](examples/linux/linux_glfw.zig)
- macOS GLFW + Metal: [macos_glfw.zig](examples/macos/macos_glfw.zig)
- Windows GLFW + Vulkan: [windows_glfw.zig](examples/windows/windows_glfw.zig)

## macOS notes

The macOS example uses GLFW for window creation and Impeller's Metal backend for rendering. A small Objective-C glue file ([macos_glfw_metal.m](examples/macos/macos_glfw_metal.m)) attaches a `CAMetalLayer` to the GLFW-owned `NSView` and hands `CAMetalDrawable` instances back to Zig each frame.

## Linux notes

The Linux example uses GLFW for window creation and Impeller's Vulkan backend for rendering.

Available GLFW modes:

- `auto`
- `x11`
- `wayland`

```bash
zig build -Dexample=linux -Dglfw=auto
zig build -Dexample=linux -Dglfw=x11
zig build -Dexample=linux -Dglfw=wayland
zig build run -Dexample=linux -Dglfw=x11
```

If the Linux example shows a white window or missing geometry, try `-Dglfw=x11` first.

On local KDE Plasma testing:

- `x11` / XWayland renders correctly
- `wayland` may show a white window or missing geometry

The same behavior can be reproduced in the upstream Impeller Vulkan C sample, so this should not automatically be treated as a Zig binding bug.

## Windows notes

The Windows example uses GLFW for window creation and Impeller's Vulkan backend for rendering. The drawing pipeline mirrors the Linux example because Impeller ships only a Vulkan backend on Windows.

Both `x86_64` and `aarch64` Windows targets are supported (the matching SDK lives under `vendor/impeller/lib/windows/{x64,arm64}`).

The build step copies `impeller.dll` next to the produced executable, so a plain `zig build run -Dexample=windows` works out of the box. A working Vulkan ICD/loader (`vulkan-1.dll`) must still be available on the system &mdash; install a recent GPU driver or the official Vulkan SDK if Impeller fails to initialize the Vulkan context.
