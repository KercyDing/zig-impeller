# zig-impeller

`zig-impeller` provides Zig bindings for the Impeller C API and a small set of desktop examples.

## Status

Impeller currently appears to prioritize mobile platforms, and desktop support remains immature in practice. This repository focuses on desktop usage, so platform-specific issues are expected, especially on Linux.

In local KDE Plasma testing, the Linux Vulkan path behaves differently across windowing platforms:

- `x11` / XWayland: both the official Impeller Vulkan C sample and this Zig example render correctly
- `wayland`: both the official sample and this repository may display a white window or missing geometry

Because the same behavior can be reproduced in the upstream C sample, such issues should not automatically be attributed to defects in this repository's Zig bindings.

## Build and run

If `-Dexample` is omitted, the build defaults to the current host platform.

Build:

```bash
zig build -Dexample=linux
zig build -Dexample=macos
```

Run:

```bash
zig build run -Dexample=linux
zig build run -Dexample=macos
```

## Linux notes

The Linux example uses GLFW for window creation and Vulkan surface integration. Rendering still uses Impeller's Vulkan backend.

Available GLFW modes:

- `auto`
- `x11`
- `wayland`

Examples:

```bash
zig build -Dexample=linux -Dglfw=auto
zig build -Dexample=linux -Dglfw=x11
zig build -Dexample=linux -Dglfw=wayland
zig build run -Dexample=linux -Dglfw=x11
```

If the Linux example shows a white window or missing geometry, try `-Dglfw=x11` first.

## Examples

- Linux GLFW + Vulkan: `examples/linux/linux_glfw.zig`
- macOS Metal: `examples/macos/macos_metal.zig`
