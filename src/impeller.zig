pub const c = @import("c.zig").impeller;

pub const Error = error{
    VersionMismatch,
    CreateContextFailed,
    CreatePaintFailed,
    CreateDisplayListBuilderFailed,
    CreateDisplayListFailed,
    CreateVulkanSwapchainFailed,
    AcquireSurfaceFailed,
    DrawFailed,
    PresentFailed,
};

pub const version = c.IMPELLER_VERSION;

pub const ColorSpace = c.ImpellerColorSpace;
pub const PixelFormat = c.ImpellerPixelFormat;
pub const TextureSampling = c.ImpellerTextureSampling;
pub const FillType = c.ImpellerFillType;
pub const ClipOperation = c.ImpellerClipOperation;
pub const BlendMode = c.ImpellerBlendMode;
pub const DrawStyle = c.ImpellerDrawStyle;
pub const StrokeCap = c.ImpellerStrokeCap;
pub const StrokeJoin = c.ImpellerStrokeJoin;
pub const TileMode = c.ImpellerTileMode;
pub const BlurStyle = c.ImpellerBlurStyle;

pub const Point = c.ImpellerPoint;
pub const Size = c.ImpellerSize;
pub const ISize = c.ImpellerISize;
pub const Rect = c.ImpellerRect;
pub const Matrix = c.ImpellerMatrix;
pub const RoundingRadii = c.ImpellerRoundingRadii;
pub const VulkanInfo = c.ImpellerContextVulkanInfo;
pub const VulkanSettings = c.ImpellerContextVulkanSettings;

pub const Color = c.ImpellerColor;

/// Creates an sRGB color value for Impeller drawing APIs.
pub fn srgb(red: f32, green: f32, blue: f32, alpha: f32) Color {
    return .{
        .red = red,
        .green = green,
        .blue = blue,
        .alpha = alpha,
        .color_space = c.kImpellerColorSpaceSRGB,
    };
}

/// Returns the linked Impeller runtime version.
pub fn runtimeVersion() u32 {
    return c.ImpellerGetVersion();
}

/// Verifies that the imported header version matches the linked runtime.
pub fn checkVersion() Error!void {
    if (runtimeVersion() != version) return Error.VersionMismatch;
}

pub const Context = struct {
    handle: c.ImpellerContext,

    /// Creates a Vulkan Impeller context from user-provided Vulkan resolver settings.
    pub fn initVulkan(settings: VulkanSettings) Error!Context {
        try checkVersion();
        var local_settings = settings;
        const handle = c.ImpellerContextCreateVulkanNew(version, &local_settings) orelse return Error.CreateContextFailed;
        return .{ .handle = handle };
    }

    /// Creates a Metal Impeller context using the system default Metal device.
    pub fn initMetal() Error!Context {
        try checkVersion();
        const handle = c.ImpellerContextCreateMetalNew(version) orelse return Error.CreateContextFailed;
        return .{ .handle = handle };
    }

    /// Creates an OpenGL ES Impeller context using a GL procedure resolver.
    pub fn initOpenGLES(callback: c.ImpellerProcAddressCallback, user_data: ?*anyopaque) Error!Context {
        try checkVersion();
        const handle = c.ImpellerContextCreateOpenGLESNew(version, callback, user_data) orelse return Error.CreateContextFailed;
        return .{ .handle = handle };
    }

    /// Releases this context reference.
    pub fn deinit(self: *Context) void {
        c.ImpellerContextRelease(self.handle);
        self.handle = null;
    }

    /// Reads Vulkan handles owned by this context.
    pub fn vulkanInfo(self: Context) ?VulkanInfo {
        var info: VulkanInfo = .{};
        if (!c.ImpellerContextGetVulkanInfo(self.handle, &info)) return null;
        return info;
    }
};

pub const Paint = struct {
    handle: c.ImpellerPaint,

    /// Creates a paint object with Impeller defaults.
    pub fn init() Error!Paint {
        const handle = c.ImpellerPaintNew() orelse return Error.CreatePaintFailed;
        return .{ .handle = handle };
    }

    /// Releases this paint reference.
    pub fn deinit(self: *Paint) void {
        c.ImpellerPaintRelease(self.handle);
        self.handle = null;
    }

    /// Sets the paint color.
    pub fn setColor(self: Paint, color: Color) void {
        var local_color = color;
        c.ImpellerPaintSetColor(self.handle, &local_color);
    }

    /// Sets the paint blend mode.
    pub fn setBlendMode(self: Paint, mode: BlendMode) void {
        c.ImpellerPaintSetBlendMode(self.handle, mode);
    }

    /// Sets whether this paint fills, strokes, or does both.
    pub fn setDrawStyle(self: Paint, style: DrawStyle) void {
        c.ImpellerPaintSetDrawStyle(self.handle, style);
    }

    /// Sets the stroke width used by this paint.
    pub fn setStrokeWidth(self: Paint, width: f32) void {
        c.ImpellerPaintSetStrokeWidth(self.handle, width);
    }
};

pub const DisplayList = struct {
    handle: c.ImpellerDisplayList,

    /// Releases this display list reference.
    pub fn deinit(self: *DisplayList) void {
        c.ImpellerDisplayListRelease(self.handle);
        self.handle = null;
    }
};

pub const DisplayListBuilder = struct {
    handle: c.ImpellerDisplayListBuilder,

    /// Creates a display list builder with an optional cull rect.
    pub fn init(cull_rect: ?Rect) Error!DisplayListBuilder {
        var local_rect = cull_rect;
        const rect_ptr = if (local_rect) |*rect| rect else null;
        const handle = c.ImpellerDisplayListBuilderNew(rect_ptr) orelse return Error.CreateDisplayListBuilderFailed;
        return .{ .handle = handle };
    }

    /// Releases this display list builder reference.
    pub fn deinit(self: *DisplayListBuilder) void {
        c.ImpellerDisplayListBuilderRelease(self.handle);
        self.handle = null;
    }

    /// Builds an immutable display list and resets the builder.
    pub fn build(self: DisplayListBuilder) Error!DisplayList {
        const handle = c.ImpellerDisplayListBuilderCreateDisplayListNew(self.handle) orelse return Error.CreateDisplayListFailed;
        return .{ .handle = handle };
    }

    /// Draws a rectangle into the display list.
    pub fn drawRect(self: DisplayListBuilder, rect: Rect, paint: Paint) void {
        var local_rect = rect;
        c.ImpellerDisplayListBuilderDrawRect(self.handle, &local_rect, paint.handle);
    }

    /// Draws a paint over the current clip.
    pub fn drawPaint(self: DisplayListBuilder, paint: Paint) void {
        c.ImpellerDisplayListBuilderDrawPaint(self.handle, paint.handle);
    }

    /// Applies a translation to the current transform.
    pub fn translate(self: DisplayListBuilder, x: f32, y: f32) void {
        c.ImpellerDisplayListBuilderTranslate(self.handle, x, y);
    }
};

pub const Surface = struct {
    handle: c.ImpellerSurface,

    /// Wraps an existing framebuffer object as an Impeller surface.
    pub fn wrapFBO(context: Context, fbo: u64, format: PixelFormat, size: ISize) Error!Surface {
        var local_size = size;
        const handle = c.ImpellerSurfaceCreateWrappedFBONew(context.handle, fbo, format, &local_size) orelse return Error.AcquireSurfaceFailed;
        return .{ .handle = handle };
    }

    /// Releases this surface reference.
    pub fn deinit(self: *Surface) void {
        c.ImpellerSurfaceRelease(self.handle);
        self.handle = null;
    }

    /// Draws a display list onto this surface.
    pub fn draw(self: Surface, display_list: DisplayList) Error!void {
        if (!c.ImpellerSurfaceDrawDisplayList(self.handle, display_list.handle)) return Error.DrawFailed;
    }

    /// Presents this surface to the window system.
    pub fn present(self: Surface) Error!void {
        if (!c.ImpellerSurfacePresent(self.handle)) return Error.PresentFailed;
    }
};

pub const VulkanSwapchain = struct {
    handle: c.ImpellerVulkanSwapchain,

    /// Creates a Vulkan swapchain and transfers VkSurfaceKHR ownership to Impeller.
    pub fn init(context: Context, vulkan_surface_khr: *anyopaque) Error!VulkanSwapchain {
        const handle = c.ImpellerVulkanSwapchainCreateNew(context.handle, vulkan_surface_khr) orelse return Error.CreateVulkanSwapchainFailed;
        return .{ .handle = handle };
    }

    /// Releases this Vulkan swapchain reference.
    pub fn deinit(self: *VulkanSwapchain) void {
        c.ImpellerVulkanSwapchainRelease(self.handle);
        self.handle = null;
    }

    /// Acquires the next renderable surface from this swapchain.
    pub fn acquireNextSurface(self: VulkanSwapchain) Error!Surface {
        const handle = c.ImpellerVulkanSwapchainAcquireNextSurfaceNew(self.handle) orelse return Error.AcquireSurfaceFailed;
        return .{ .handle = handle };
    }
};

test "version" {
    try checkVersion();
}
