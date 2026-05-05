#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stdio.h>

#include "impeller.h"

static bool g_should_close = false;

@interface ImpellerWindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation ImpellerWindowDelegate
- (BOOL)windowShouldClose:(id)sender {
  g_should_close = true;
  return YES;
}
@end

static ImpellerDisplayList CreateDisplayList(void) {
  ImpellerDisplayListBuilder builder = ImpellerDisplayListBuilderNew(NULL);
  ImpellerPaint paint = ImpellerPaintNew();

  ImpellerColor clear_color = {1.0, 1.0, 1.0, 1.0};
  ImpellerPaintSetColor(paint, &clear_color);
  ImpellerDisplayListBuilderDrawPaint(builder, paint);

  ImpellerColor box_color = {1.0, 0.0, 0.0, 1.0};
  ImpellerPaintSetColor(paint, &box_color);
  ImpellerRect box_rect = {10, 10, 100, 100};
  ImpellerDisplayListBuilderDrawRect(builder, &box_rect, paint);

  ImpellerDisplayList display_list =
      ImpellerDisplayListBuilderCreateDisplayListNew(builder);

  ImpellerPaintRelease(paint);
  ImpellerDisplayListBuilderRelease(builder);
  return display_list;
}

static void PumpEvents(void) {
  for (;;) {
    NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                        untilDate:[NSDate distantPast]
                                           inMode:NSDefaultRunLoopMode
                                          dequeue:YES];
    if (event == nil) {
      break;
    }
    [NSApp sendEvent:event];
  }
}

int runMetalExample(void) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    id menubar = [NSMenu new];
    id app_menu_item = [NSMenuItem new];
    [menubar addItem:app_menu_item];
    [NSApp setMainMenu:menubar];

    id app_menu = [NSMenu new];
    id quit_title = @"Quit zig-impeller";
    id quit_item = [[NSMenuItem alloc] initWithTitle:quit_title
                                             action:@selector(terminate:)
                                      keyEquivalent:@"q"];
    [app_menu addItem:quit_item];
    [app_menu_item setSubmenu:app_menu];

    NSRect frame = NSMakeRect(0, 0, 800, 600);
    NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                       NSWindowStyleMaskMiniaturizable |
                       NSWindowStyleMaskResizable;
    NSWindow* window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window center];
    [window setTitle:@"zig-impeller Metal" ];

    ImpellerWindowDelegate* delegate = [[ImpellerWindowDelegate alloc] init];
    [window setDelegate:delegate];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
      fprintf(stderr, "Metal device unavailable.\n");
      return 1;
    }

    CAMetalLayer* layer = [CAMetalLayer layer];
    layer.framebufferOnly = NO;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.device = device;
    window.contentView.layer = layer;
    window.contentView.wantsLayer = YES;

    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    if (ImpellerGetVersion() != IMPELLER_VERSION) {
      fprintf(stderr, "Impeller version mismatch.\n");
      return 1;
    }

    ImpellerContext context = ImpellerContextCreateMetalNew(IMPELLER_VERSION);
    if (context == NULL) {
      fprintf(stderr, "Could not create Impeller Metal context.\n");
      return 1;
    }

    ImpellerDisplayList display_list = CreateDisplayList();
    if (display_list == NULL) {
      fprintf(stderr, "Could not create display list.\n");
      ImpellerContextRelease(context);
      return 1;
    }

    while (!g_should_close) {
      @autoreleasepool {
        PumpEvents();

        layer.drawableSize = layer.bounds.size;
        id<CAMetalDrawable> drawable = [layer nextDrawable];
        if (drawable == nil) {
          continue;
        }

        ImpellerSurface surface = ImpellerSurfaceCreateWrappedMetalDrawableNew(
            context, (__bridge void*)drawable);
        if (surface == NULL) {
          continue;
        }

        ImpellerSurfaceDrawDisplayList(surface, display_list);
        ImpellerSurfacePresent(surface);
        ImpellerSurfaceRelease(surface);
      }
    }

    ImpellerDisplayListRelease(display_list);
    ImpellerContextRelease(context);
  }
  return 0;
}
