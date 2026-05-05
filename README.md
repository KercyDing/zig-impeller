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

zig build run -Dexample=linux
zig build run -Dexample=macos
```

## Examples

- Linux GLFW + Vulkan: [linux_glfw.zig](examples/linux/linux_glfw.zig)
- macOS Metal: [macos_metal.zig](examples/macos/macos_metal.zig)

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
