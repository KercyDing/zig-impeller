pub const c = @import("impeller_c");

pub const Error = error{
    VersionMismatch,
    CreateContextFailed,
    CreatePaintFailed,
    CreateColorFilterFailed,
    CreateDisplayListBuilderFailed,
    CreateDisplayListFailed,
    CreatePathBuilderFailed,
    CreatePathFailed,
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
pub const ColorMatrix = c.ImpellerColorMatrix;
pub const RoundingRadii = c.ImpellerRoundingRadii;
pub const VulkanInfo = c.ImpellerContextVulkanInfo;
pub const VulkanSettings = c.ImpellerContextVulkanSettings;

pub const Color = c.ImpellerColor;
pub const ImageFilterHandle = c.ImpellerImageFilter;

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

    /// Returns the underlying Impeller paint handle.
    pub fn raw(self: Paint) c.ImpellerPaint {
        return self.handle;
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

    /// Sets the color filter applied by this paint.
    pub fn setColorFilter(self: Paint, color_filter: ColorFilter) void {
        c.ImpellerPaintSetColorFilter(self.handle, color_filter.handle);
    }
};

pub const ColorFilter = struct {
    handle: c.ImpellerColorFilter,

    /// Creates a color filter that blends every sampled color with the provided color.
    pub fn initBlend(color: Color, blend_mode: BlendMode) Error!ColorFilter {
        var local_color = color;
        const handle = c.ImpellerColorFilterCreateBlendNew(&local_color, blend_mode) orelse return Error.CreateColorFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a color filter from a 4x5 color matrix.
    pub fn initColorMatrix(color_matrix: ColorMatrix) Error!ColorFilter {
        var local_color_matrix = color_matrix;
        const handle = c.ImpellerColorFilterCreateColorMatrixNew(&local_color_matrix) orelse return Error.CreateColorFilterFailed;
        return .{ .handle = handle };
    }

    /// Retains this color filter reference.
    pub fn retain(self: ColorFilter) void {
        c.ImpellerColorFilterRetain(self.handle);
    }

    /// Releases this color filter reference.
    pub fn deinit(self: *ColorFilter) void {
        c.ImpellerColorFilterRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller color filter handle.
    pub fn raw(self: ColorFilter) c.ImpellerColorFilter {
        return self.handle;
    }
};

pub const ImageFilter = struct {
    handle: c.ImpellerImageFilter,

    /// Creates a Gaussian blur image filter.
    pub fn initBlur(x_sigma: f32, y_sigma: f32, tile_mode: TileMode) ?ImageFilter {
        const handle = c.ImpellerImageFilterCreateBlurNew(x_sigma, y_sigma, tile_mode) orelse return null;
        return .{ .handle = handle };
    }

    /// Releases this image filter reference.
    pub fn deinit(self: *ImageFilter) void {
        c.ImpellerImageFilterRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller image filter handle.
    pub fn raw(self: ImageFilter) c.ImpellerImageFilter {
        return self.handle;
    }
};

pub const Path = struct {
    handle: c.ImpellerPath,

    /// Releases this path reference.
    pub fn deinit(self: *Path) void {
        c.ImpellerPathRelease(self.handle);
        self.handle = null;
    }

    /// Returns the conservative bounds of this path.
    pub fn getBounds(self: Path) Rect {
        var bounds: Rect = undefined;
        c.ImpellerPathGetBounds(self.handle, &bounds);
        return bounds;
    }

    /// Returns the underlying Impeller path handle.
    pub fn raw(self: Path) c.ImpellerPath {
        return self.handle;
    }
};

pub const PathBuilder = struct {
    handle: c.ImpellerPathBuilder,

    /// Creates a new path builder.
    pub fn init() Error!PathBuilder {
        const handle = c.ImpellerPathBuilderNew() orelse return Error.CreatePathBuilderFailed;
        return .{ .handle = handle };
    }

    /// Releases this path builder reference.
    pub fn deinit(self: *PathBuilder) void {
        c.ImpellerPathBuilderRelease(self.handle);
        self.handle = null;
    }

    /// Moves the current point to the specified location.
    pub fn moveTo(self: PathBuilder, location: Point) void {
        var local_point = location;
        c.ImpellerPathBuilderMoveTo(self.handle, &local_point);
    }

    /// Adds a line segment to the specified location.
    pub fn lineTo(self: PathBuilder, location: Point) void {
        var local_point = location;
        c.ImpellerPathBuilderLineTo(self.handle, &local_point);
    }

    /// Adds a quadratic curve to the specified end point.
    pub fn quadraticCurveTo(self: PathBuilder, control_point: Point, end_point: Point) void {
        var local_control_point = control_point;
        var local_end_point = end_point;
        c.ImpellerPathBuilderQuadraticCurveTo(self.handle, &local_control_point, &local_end_point);
    }

    /// Adds a cubic curve to the specified end point.
    pub fn cubicCurveTo(self: PathBuilder, control_point_1: Point, control_point_2: Point, end_point: Point) void {
        var local_control_point_1 = control_point_1;
        var local_control_point_2 = control_point_2;
        var local_end_point = end_point;
        c.ImpellerPathBuilderCubicCurveTo(self.handle, &local_control_point_1, &local_control_point_2, &local_end_point);
    }

    /// Adds a rectangle to the path.
    pub fn addRect(self: PathBuilder, rectangle: Rect) void {
        var local_rect = rectangle;
        c.ImpellerPathBuilderAddRect(self.handle, &local_rect);
    }

    /// Adds an arc to the path.
    pub fn addArc(self: PathBuilder, oval_bounds: Rect, start_angle_degrees: f32, end_angle_degrees: f32) void {
        var local_rect = oval_bounds;
        c.ImpellerPathBuilderAddArc(self.handle, &local_rect, start_angle_degrees, end_angle_degrees);
    }

    /// Adds an oval to the path.
    pub fn addOval(self: PathBuilder, oval_bounds: Rect) void {
        var local_rect = oval_bounds;
        c.ImpellerPathBuilderAddOval(self.handle, &local_rect);
    }

    /// Adds a rounded rectangle to the path.
    pub fn addRoundedRect(self: PathBuilder, rectangle: Rect, radii: RoundingRadii) void {
        var local_rect = rectangle;
        var local_radii = radii;
        c.ImpellerPathBuilderAddRoundedRect(self.handle, &local_rect, &local_radii);
    }

    /// Closes the current contour.
    pub fn close(self: PathBuilder) void {
        c.ImpellerPathBuilderClose(self.handle);
    }

    /// Copies the current path without resetting the builder.
    pub fn copyPath(self: PathBuilder, fill: FillType) Error!Path {
        const handle = c.ImpellerPathBuilderCopyPathNew(self.handle, fill) orelse return Error.CreatePathFailed;
        return .{ .handle = handle };
    }

    /// Takes the current path and resets the builder.
    pub fn takePath(self: PathBuilder, fill: FillType) Error!Path {
        const handle = c.ImpellerPathBuilderTakePathNew(self.handle, fill) orelse return Error.CreatePathFailed;
        return .{ .handle = handle };
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
        const cull_rect_ptr = if (local_rect) |*cull_rect_value| cull_rect_value else null;
        const handle = c.ImpellerDisplayListBuilderNew(cull_rect_ptr) orelse return Error.CreateDisplayListBuilderFailed;
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
    pub fn drawRect(self: DisplayListBuilder, rectangle: Rect, paint: Paint) void {
        var local_rect = rectangle;
        c.ImpellerDisplayListBuilderDrawRect(self.handle, &local_rect, paint.handle);
    }

    /// Draws an oval into the display list.
    pub fn drawOval(self: DisplayListBuilder, oval_bounds: Rect, paint: Paint) void {
        var local_rect = oval_bounds;
        c.ImpellerDisplayListBuilderDrawOval(self.handle, &local_rect, paint.handle);
    }

    /// Draws a rounded rectangle into the display list.
    pub fn drawRoundedRect(self: DisplayListBuilder, rectangle: Rect, radii: RoundingRadii, paint: Paint) void {
        var local_rect = rectangle;
        var local_radii = radii;
        c.ImpellerDisplayListBuilderDrawRoundedRect(self.handle, &local_rect, &local_radii, paint.handle);
    }

    /// Draws the difference between two rounded rectangles.
    pub fn drawRoundedRectDifference(
        self: DisplayListBuilder,
        outer_rect: Rect,
        outer_radii: RoundingRadii,
        inner_rect: Rect,
        inner_radii: RoundingRadii,
        paint: Paint,
    ) void {
        var local_outer_rect = outer_rect;
        var local_outer_radii = outer_radii;
        var local_inner_rect = inner_rect;
        var local_inner_radii = inner_radii;
        c.ImpellerDisplayListBuilderDrawRoundedRectDifference(
            self.handle,
            &local_outer_rect,
            &local_outer_radii,
            &local_inner_rect,
            &local_inner_radii,
            paint.handle,
        );
    }

    /// Draws the specified shape.
    pub fn drawPath(self: DisplayListBuilder, path: Path, paint: Paint) void {
        c.ImpellerDisplayListBuilderDrawPath(self.handle, path.raw(), paint.handle);
    }

    /// Flattens another display list into this one.
    pub fn drawDisplayList(self: DisplayListBuilder, display_list: DisplayList, opacity: f32) void {
        c.ImpellerDisplayListBuilderDrawDisplayList(self.handle, display_list.handle, opacity);
    }

    /// Draws a paint over the current clip.
    pub fn drawPaint(self: DisplayListBuilder, paint: Paint) void {
        c.ImpellerDisplayListBuilderDrawPaint(self.handle, paint.handle);
    }

    /// Saves the current clip and transform state.
    pub fn save(self: DisplayListBuilder) void {
        c.ImpellerDisplayListBuilderSave(self.handle);
    }

    /// Saves a new layer with optional paint and backdrop filtering.
    pub fn saveLayer(self: DisplayListBuilder, bounds: Rect, paint: ?Paint, backdrop: ?ImageFilter) void {
        var local_bounds = bounds;
        c.ImpellerDisplayListBuilderSaveLayer(
            self.handle,
            &local_bounds,
            if (paint) |value| value.raw() else null,
            if (backdrop) |value| value.raw() else null,
        );
    }

    /// Returns the current save stack depth.
    pub fn getSaveCount(self: DisplayListBuilder) u32 {
        return c.ImpellerDisplayListBuilderGetSaveCount(self.handle);
    }

    /// Restores the save stack until it reaches the requested depth.
    pub fn restoreToCount(self: DisplayListBuilder, count: u32) void {
        c.ImpellerDisplayListBuilderRestoreToCount(self.handle, count);
    }

    /// Restores the last saved clip and transform state.
    pub fn restore(self: DisplayListBuilder) void {
        c.ImpellerDisplayListBuilderRestore(self.handle);
    }

    /// Clips subsequent drawing operations to a rectangle.
    pub fn clipRect(self: DisplayListBuilder, rectangle: Rect, operation: ClipOperation) void {
        var local_rect = rectangle;
        c.ImpellerDisplayListBuilderClipRect(self.handle, &local_rect, operation);
    }

    /// Applies a scale transform to the current transform.
    pub fn scale(self: DisplayListBuilder, x: f32, y: f32) void {
        c.ImpellerDisplayListBuilderScale(self.handle, x, y);
    }

    /// Applies a rotation transform in degrees to the current transform.
    pub fn rotate(self: DisplayListBuilder, degrees: f32) void {
        c.ImpellerDisplayListBuilderRotate(self.handle, degrees);
    }

    /// Applies a translation to the current transform.
    pub fn translate(self: DisplayListBuilder, x: f32, y: f32) void {
        c.ImpellerDisplayListBuilderTranslate(self.handle, x, y);
    }

    /// Appends a transform to the current transform.
    pub fn transform(self: DisplayListBuilder, matrix: Matrix) void {
        var local_matrix = matrix;
        c.ImpellerDisplayListBuilderTransform(self.handle, &local_matrix);
    }

    /// Replaces the current transform.
    pub fn setTransform(self: DisplayListBuilder, matrix: Matrix) void {
        var local_matrix = matrix;
        c.ImpellerDisplayListBuilderSetTransform(self.handle, &local_matrix);
    }

    /// Returns the current transform.
    pub fn getTransform(self: DisplayListBuilder) Matrix {
        var matrix: Matrix = undefined;
        c.ImpellerDisplayListBuilderGetTransform(self.handle, &matrix);
        return matrix;
    }

    /// Resets the current transform to identity.
    pub fn resetTransform(self: DisplayListBuilder) void {
        c.ImpellerDisplayListBuilderResetTransform(self.handle);
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

pub fn rect(x: f32, y: f32, width: f32, height: f32) Rect {
    return .{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };
}

pub fn point(x: f32, y: f32) Point {
    return .{
        .x = x,
        .y = y,
    };
}

pub fn uniformRadii(radius: f32) RoundingRadii {
    const corner = point(radius, radius);
    return .{
        .top_left = corner,
        .bottom_left = corner,
        .top_right = corner,
        .bottom_right = corner,
    };
}

pub fn colorMatrix(values: [20]f32) ColorMatrix {
    return .{ .m = values };
}

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
