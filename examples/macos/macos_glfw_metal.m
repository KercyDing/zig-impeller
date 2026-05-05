#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#include "macos_glfw_metal.h"

void* macosGlfwAttachMetalLayer(void* nsview) {
    if (nsview == NULL) {
        return NULL;
    }
    NSView* view = (__bridge NSView*)nsview;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        return NULL;
    }
    CAMetalLayer* layer = [CAMetalLayer layer];
    layer.framebufferOnly = NO;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.device = device;
    view.layer = layer;
    view.wantsLayer = YES;
    // The view now retains the layer; hand back an unowned pointer.
    return (__bridge void*)layer;
}

void* macosGlfwAcquireNextDrawable(void* layer_ptr, double width, double height) {
    if (layer_ptr == NULL) {
        return NULL;
    }
    @autoreleasepool {
        CAMetalLayer* layer = (__bridge CAMetalLayer*)layer_ptr;
        if (width > 0.0 && height > 0.0) {
            layer.drawableSize = CGSizeMake(width, height);
        }
        id<CAMetalDrawable> drawable = [layer nextDrawable];
        if (drawable == nil) {
            return NULL;
        }
        // Transfer +1 retain to the caller; Zig releases it after present.
        return (__bridge_retained void*)drawable;
    }
}

void macosGlfwReleaseDrawable(void* drawable_ptr) {
    if (drawable_ptr == NULL) {
        return;
    }
    // Reclaim the retain count taken in macosGlfwAcquireNextDrawable.
    id drawable = (__bridge_transfer id)drawable_ptr;
    (void)drawable;
}
