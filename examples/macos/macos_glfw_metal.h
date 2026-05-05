/// Cocoa glue for the GLFW + Metal example.
///
/// Keeps Objective-C exclusively in `macos_glfw_metal.m` so the Zig
/// example mirrors `linux_glfw.zig` and stays free of `objc_msgSend`.
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/// Attaches a fresh `CAMetalLayer` (BGRA8Unorm, framebufferOnly = NO) to
/// the supplied `NSView*`. Returns the layer pointer (unowned, lifetime
/// tied to the view) or NULL when no Metal device is available.
void* macosGlfwAttachMetalLayer(void* nsview);

/// Updates the layer drawable size and acquires the next `CAMetalDrawable`.
/// Width/height of zero or less keeps the existing drawable size. The
/// returned drawable is retained (+1) and must be released via
/// `macosGlfwReleaseDrawable` after Impeller has finished with it.
void* macosGlfwAcquireNextDrawable(void* layer, double width, double height);

/// Releases (-1) a drawable previously returned by `macosGlfwAcquireNextDrawable`.
/// Safe to call with NULL.
void macosGlfwReleaseDrawable(void* drawable);

#ifdef __cplusplus
}
#endif
