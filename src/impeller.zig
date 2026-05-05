pub const c = @import("impeller_c");

pub const Error = error{
    VersionMismatch,
    CreateContextFailed,
    CreatePaintFailed,
    CreateColorSourceFailed,
    CreateColorFilterFailed,
    CreateMaskFilterFailed,
    CreateImageFilterFailed,
    CreateTextureFailed,
    CreateFragmentProgramFailed,
    CreateDisplayListBuilderFailed,
    CreateDisplayListFailed,
    CreatePathBuilderFailed,
    CreatePathFailed,
    CreateTypographyContextFailed,
    RegisterFontFailed,
    CreateParagraphStyleFailed,
    CreateParagraphBuilderFailed,
    CreateParagraphFailed,
    CreateLineMetricsFailed,
    CreateGlyphInfoFailed,
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
pub const FontWeight = c.ImpellerFontWeight;
pub const FontStyle = c.ImpellerFontStyle;
pub const TextAlignment = c.ImpellerTextAlignment;
pub const TextDirection = c.ImpellerTextDirection;
pub const TextDecorationType = c.ImpellerTextDecorationType;
pub const TextDecorationStyle = c.ImpellerTextDecorationStyle;

pub const Point = c.ImpellerPoint;
pub const Size = c.ImpellerSize;
pub const ISize = c.ImpellerISize;
pub const Range = c.ImpellerRange;
pub const Rect = c.ImpellerRect;
pub const Matrix = c.ImpellerMatrix;
pub const ColorMatrix = c.ImpellerColorMatrix;
pub const RoundingRadii = c.ImpellerRoundingRadii;
pub const VulkanInfo = c.ImpellerContextVulkanInfo;
pub const VulkanSettings = c.ImpellerContextVulkanSettings;
pub const TextDecoration = c.ImpellerTextDecoration;

pub const Color = c.ImpellerColor;
pub const Mapping = c.ImpellerMapping;
pub const TextureDescriptor = c.ImpellerTextureDescriptor;
pub const ImageFilterHandle = c.ImpellerImageFilter;
pub const TextureHandle = c.ImpellerTexture;

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

    /// Retains this context reference.
    pub fn retain(self: Context) void {
        c.ImpellerContextRetain(self.handle);
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

    /// Retains this paint reference.
    pub fn retain(self: Paint) void {
        c.ImpellerPaintRetain(self.handle);
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

    /// Sets how open stroke ends are capped.
    pub fn setStrokeCap(self: Paint, cap: StrokeCap) void {
        c.ImpellerPaintSetStrokeCap(self.handle, cap);
    }

    /// Sets how connected stroke segments are joined.
    pub fn setStrokeJoin(self: Paint, join: StrokeJoin) void {
        c.ImpellerPaintSetStrokeJoin(self.handle, join);
    }

    /// Sets the stroke width used by this paint.
    pub fn setStrokeWidth(self: Paint, width: f32) void {
        c.ImpellerPaintSetStrokeWidth(self.handle, width);
    }

    /// Sets the stroke miter limit used by this paint.
    pub fn setStrokeMiter(self: Paint, miter: f32) void {
        c.ImpellerPaintSetStrokeMiter(self.handle, miter);
    }

    /// Sets the color source applied by this paint.
    pub fn setColorSource(self: Paint, color_source: ColorSource) void {
        c.ImpellerPaintSetColorSource(self.handle, color_source.handle);
    }

    /// Sets the color filter applied by this paint.
    pub fn setColorFilter(self: Paint, color_filter: ColorFilter) void {
        c.ImpellerPaintSetColorFilter(self.handle, color_filter.handle);
    }

    /// Sets the mask filter applied by this paint.
    pub fn setMaskFilter(self: Paint, mask_filter: MaskFilter) void {
        c.ImpellerPaintSetMaskFilter(self.handle, mask_filter.handle);
    }

    /// Sets the image filter applied by this paint.
    pub fn setImageFilter(self: Paint, image_filter: ImageFilter) void {
        c.ImpellerPaintSetImageFilter(self.handle, image_filter.handle);
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

pub const ColorSource = struct {
    handle: c.ImpellerColorSource,

    /// Creates a linear gradient color source.
    pub fn initLinearGradient(
        start_point: Point,
        end_point: Point,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_start_point = start_point;
        var local_end_point = end_point;
        var local_transformation = transformation;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateLinearGradientNew(
            &local_start_point,
            &local_end_point,
            @intCast(colors.len),
            colors.ptr,
            stops.ptr,
            tile_mode,
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a radial gradient color source.
    pub fn initRadialGradient(
        center: Point,
        radius: f32,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_center = center;
        var local_transformation = transformation;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateRadialGradientNew(
            &local_center,
            radius,
            @intCast(colors.len),
            colors.ptr,
            stops.ptr,
            tile_mode,
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a conical gradient color source.
    pub fn initConicalGradient(
        start_center: Point,
        start_radius: f32,
        end_center: Point,
        end_radius: f32,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_start_center = start_center;
        var local_end_center = end_center;
        var local_transformation = transformation;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateConicalGradientNew(
            &local_start_center,
            start_radius,
            &local_end_center,
            end_radius,
            @intCast(colors.len),
            colors.ptr,
            stops.ptr,
            tile_mode,
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a sweep gradient color source.
    pub fn initSweepGradient(
        center: Point,
        start_angle: f32,
        end_angle: f32,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_center = center;
        var local_transformation = transformation;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateSweepGradientNew(
            &local_center,
            start_angle,
            end_angle,
            @intCast(colors.len),
            colors.ptr,
            stops.ptr,
            tile_mode,
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates an image-backed color source.
    pub fn initImage(
        texture: Texture,
        horizontal_tile_mode: TileMode,
        vertical_tile_mode: TileMode,
        sampling: TextureSampling,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_transformation = transformation;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateImageNew(
            texture.handle,
            horizontal_tile_mode,
            vertical_tile_mode,
            sampling,
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a fragment-program color source.
    pub fn initFragmentProgram(
        context: Context,
        fragment_program: FragmentProgram,
        samplers: ?[*]TextureHandle,
        samplers_count: usize,
        data: ?[*]const u8,
        data_bytes_length: usize,
    ) Error!ColorSource {
        const handle = c.ImpellerColorSourceCreateFragmentProgramNew(
            context.handle,
            fragment_program.handle,
            samplers,
            samplers_count,
            data,
            data_bytes_length,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Retains this color source reference.
    pub fn retain(self: ColorSource) void {
        c.ImpellerColorSourceRetain(self.handle);
    }

    /// Releases this color source reference.
    pub fn deinit(self: *ColorSource) void {
        c.ImpellerColorSourceRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller color source handle.
    pub fn raw(self: ColorSource) c.ImpellerColorSource {
        return self.handle;
    }
};

pub const FragmentProgram = struct {
    handle: c.ImpellerFragmentProgram,

    /// Creates a fragment program from impellerc-compiled bytes.
    pub fn init(data: Mapping) Error!FragmentProgram {
        var local_data = data;
        const handle = c.ImpellerFragmentProgramNew(&local_data, null) orelse return Error.CreateFragmentProgramFailed;
        return .{ .handle = handle };
    }

    /// Retains this fragment program reference.
    pub fn retain(self: FragmentProgram) void {
        c.ImpellerFragmentProgramRetain(self.handle);
    }

    /// Releases this fragment program reference.
    pub fn deinit(self: *FragmentProgram) void {
        c.ImpellerFragmentProgramRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller fragment program handle.
    pub fn raw(self: FragmentProgram) c.ImpellerFragmentProgram {
        return self.handle;
    }
};

pub const ImageFilter = struct {
    handle: c.ImpellerImageFilter,

    /// Creates a Gaussian blur image filter.
    pub fn initBlur(x_sigma: f32, y_sigma: f32, tile_mode: TileMode) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateBlurNew(x_sigma, y_sigma, tile_mode) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a dilate image filter.
    pub fn initDilate(x_radius: f32, y_radius: f32) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateDilateNew(x_radius, y_radius) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates an erode image filter.
    pub fn initErode(x_radius: f32, y_radius: f32) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateErodeNew(x_radius, y_radius) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a matrix image filter.
    pub fn initMatrix(matrix: Matrix, sampling: TextureSampling) Error!ImageFilter {
        var local_matrix = matrix;
        const handle = c.ImpellerImageFilterCreateMatrixNew(&local_matrix, sampling) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a fragment-program image filter.
    pub fn initFragmentProgram(
        context: Context,
        fragment_program: FragmentProgram,
        samplers: ?[*]TextureHandle,
        samplers_count: usize,
        data: ?[*]const u8,
        data_bytes_length: usize,
    ) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateFragmentProgramNew(
            context.handle,
            fragment_program.handle,
            samplers,
            samplers_count,
            data,
            data_bytes_length,
        ) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a composed image filter.
    pub fn initCompose(outer: ImageFilter, inner: ImageFilter) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateComposeNew(outer.handle, inner.handle) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Retains this image filter reference.
    pub fn retain(self: ImageFilter) void {
        c.ImpellerImageFilterRetain(self.handle);
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

pub const Texture = struct {
    handle: c.ImpellerTexture,

    /// Creates a texture from tightly packed pixel bytes.
    pub fn initWithContents(context: Context, descriptor: TextureDescriptor, contents: Mapping) Error!Texture {
        var local_descriptor = descriptor;
        var local_contents = contents;
        const handle = c.ImpellerTextureCreateWithContentsNew(context.handle, &local_descriptor, &local_contents, null) orelse return Error.CreateTextureFailed;
        return .{ .handle = handle };
    }

    /// Retains this texture reference.
    pub fn retain(self: Texture) void {
        c.ImpellerTextureRetain(self.handle);
    }

    /// Releases this texture reference.
    pub fn deinit(self: *Texture) void {
        c.ImpellerTextureRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller texture handle.
    pub fn raw(self: Texture) c.ImpellerTexture {
        return self.handle;
    }

    /// Returns the backing OpenGL texture name when available.
    pub fn getOpenGLHandle(self: Texture) u64 {
        return c.ImpellerTextureGetOpenGLHandle(self.handle);
    }
};

pub const MaskFilter = struct {
    handle: c.ImpellerMaskFilter,

    /// Creates a blur mask filter.
    pub fn initBlur(style: BlurStyle, sigma: f32) Error!MaskFilter {
        const handle = c.ImpellerMaskFilterCreateBlurNew(style, sigma) orelse return Error.CreateMaskFilterFailed;
        return .{ .handle = handle };
    }

    /// Retains this mask filter reference.
    pub fn retain(self: MaskFilter) void {
        c.ImpellerMaskFilterRetain(self.handle);
    }

    /// Releases this mask filter reference.
    pub fn deinit(self: *MaskFilter) void {
        c.ImpellerMaskFilterRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller mask filter handle.
    pub fn raw(self: MaskFilter) c.ImpellerMaskFilter {
        return self.handle;
    }
};

pub const Path = struct {
    handle: c.ImpellerPath,

    /// Retains this path reference.
    pub fn retain(self: Path) void {
        c.ImpellerPathRetain(self.handle);
    }

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

    /// Retains this path builder reference.
    pub fn retain(self: PathBuilder) void {
        c.ImpellerPathBuilderRetain(self.handle);
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

    /// Retains this display list reference.
    pub fn retain(self: DisplayList) void {
        c.ImpellerDisplayListRetain(self.handle);
    }

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

    /// Retains this display list builder reference.
    pub fn retain(self: DisplayListBuilder) void {
        c.ImpellerDisplayListBuilderRetain(self.handle);
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

    /// Draws a line segment into the display list.
    pub fn drawLine(self: DisplayListBuilder, from: Point, to: Point, paint: Paint) void {
        var local_from = from;
        var local_to = to;
        c.ImpellerDisplayListBuilderDrawLine(self.handle, &local_from, &local_to, paint.handle);
    }

    /// Draws a dashed line segment into the display list.
    pub fn drawDashedLine(self: DisplayListBuilder, from: Point, to: Point, on_length: f32, off_length: f32, paint: Paint) void {
        var local_from = from;
        var local_to = to;
        c.ImpellerDisplayListBuilderDrawDashedLine(self.handle, &local_from, &local_to, on_length, off_length, paint.handle);
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

    /// Draws a drop shadow for the specified path.
    pub fn drawShadow(
        self: DisplayListBuilder,
        path: Path,
        color: Color,
        elevation: f32,
        occluder_is_transparent: bool,
        device_pixel_ratio: f32,
    ) void {
        var local_color = color;
        c.ImpellerDisplayListBuilderDrawShadow(
            self.handle,
            path.raw(),
            &local_color,
            elevation,
            occluder_is_transparent,
            device_pixel_ratio,
        );
    }

    /// Flattens another display list into this one.
    pub fn drawDisplayList(self: DisplayListBuilder, display_list: DisplayList, opacity: f32) void {
        c.ImpellerDisplayListBuilderDrawDisplayList(self.handle, display_list.handle, opacity);
    }

    /// Draws a texture at the specified point.
    pub fn drawTexture(
        self: DisplayListBuilder,
        texture: Texture,
        point_value: Point,
        sampling: TextureSampling,
        paint: ?Paint,
    ) void {
        var local_point = point_value;
        c.ImpellerDisplayListBuilderDrawTexture(
            self.handle,
            texture.handle,
            &local_point,
            sampling,
            if (paint) |value| value.raw() else null,
        );
    }

    /// Draws a sub-rectangle of a texture into the destination rectangle.
    pub fn drawTextureRect(
        self: DisplayListBuilder,
        texture: Texture,
        src_rect: Rect,
        dst_rect: Rect,
        sampling: TextureSampling,
        paint: ?Paint,
    ) void {
        var local_src_rect = src_rect;
        var local_dst_rect = dst_rect;
        c.ImpellerDisplayListBuilderDrawTextureRect(
            self.handle,
            texture.handle,
            &local_src_rect,
            &local_dst_rect,
            sampling,
            if (paint) |value| value.raw() else null,
        );
    }

    /// Draws a paint over the current clip.
    pub fn drawPaint(self: DisplayListBuilder, paint: Paint) void {
        c.ImpellerDisplayListBuilderDrawPaint(self.handle, paint.handle);
    }

    /// Draws a laid out paragraph at the specified point.
    pub fn drawParagraph(self: DisplayListBuilder, paragraph: Paragraph, point_value: Point) void {
        var local_point = point_value;
        c.ImpellerDisplayListBuilderDrawParagraph(self.handle, paragraph.handle, &local_point);
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

    /// Clips subsequent drawing operations to an oval.
    pub fn clipOval(self: DisplayListBuilder, oval_bounds: Rect, operation: ClipOperation) void {
        var local_rect = oval_bounds;
        c.ImpellerDisplayListBuilderClipOval(self.handle, &local_rect, operation);
    }

    /// Clips subsequent drawing operations to a rounded rectangle.
    pub fn clipRoundedRect(self: DisplayListBuilder, rectangle: Rect, radii: RoundingRadii, operation: ClipOperation) void {
        var local_rect = rectangle;
        var local_radii = radii;
        c.ImpellerDisplayListBuilderClipRoundedRect(self.handle, &local_rect, &local_radii, operation);
    }

    /// Clips subsequent drawing operations to a path.
    pub fn clipPath(self: DisplayListBuilder, path: Path, operation: ClipOperation) void {
        c.ImpellerDisplayListBuilderClipPath(self.handle, path.raw(), operation);
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

    /// Retains this surface reference.
    pub fn retain(self: Surface) void {
        c.ImpellerSurfaceRetain(self.handle);
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

/// Creates a pixel size value.
pub fn pixelSize(width: i32, height: i32) ISize {
    return .{
        .width = width,
        .height = height,
    };
}

/// Creates a texture descriptor for tightly packed textures.
pub fn textureDescriptor(pixel_format: PixelFormat, size_value: ISize, mip_count: u32) TextureDescriptor {
    return .{
        .pixel_format = pixel_format,
        .size = size_value,
        .mip_count = mip_count,
    };
}

/// Creates a byte mapping that borrows caller-owned memory.
pub fn mapping(bytes: []const u8) Mapping {
    return .{
        .data = bytes.ptr,
        .length = bytes.len,
        .on_release = null,
    };
}

pub const VulkanSwapchain = struct {
    handle: c.ImpellerVulkanSwapchain,

    /// Creates a Vulkan swapchain and transfers VkSurfaceKHR ownership to Impeller.
    pub fn init(context: Context, vulkan_surface_khr: *anyopaque) Error!VulkanSwapchain {
        const handle = c.ImpellerVulkanSwapchainCreateNew(context.handle, vulkan_surface_khr) orelse return Error.CreateVulkanSwapchainFailed;
        return .{ .handle = handle };
    }

    /// Retains this Vulkan swapchain reference.
    pub fn retain(self: VulkanSwapchain) void {
        c.ImpellerVulkanSwapchainRetain(self.handle);
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

pub const TypographyContext = struct {
    handle: c.ImpellerTypographyContext,

    /// Creates a typography context used for font registration and paragraph layout.
    pub fn init() Error!TypographyContext {
        const handle = c.ImpellerTypographyContextNew() orelse return Error.CreateTypographyContextFailed;
        return .{ .handle = handle };
    }

    /// Retains this typography context reference.
    pub fn retain(self: TypographyContext) void {
        c.ImpellerTypographyContextRetain(self.handle);
    }

    /// Releases this typography context reference.
    pub fn deinit(self: *TypographyContext) void {
        c.ImpellerTypographyContextRelease(self.handle);
        self.handle = null;
    }

    /// Registers a font blob, optionally overriding its family name.
    pub fn registerFont(self: TypographyContext, contents: Mapping, family_name_alias: ?[*:0]const u8) Error!void {
        var local_contents = contents;
        if (!c.ImpellerTypographyContextRegisterFont(self.handle, &local_contents, null, family_name_alias)) {
            return Error.RegisterFontFailed;
        }
    }
};

pub const ParagraphStyle = struct {
    handle: c.ImpellerParagraphStyle,

    /// Creates a paragraph style for text layout and rendering.
    pub fn init() Error!ParagraphStyle {
        const handle = c.ImpellerParagraphStyleNew() orelse return Error.CreateParagraphStyleFailed;
        return .{ .handle = handle };
    }

    /// Retains this paragraph style reference.
    pub fn retain(self: ParagraphStyle) void {
        c.ImpellerParagraphStyleRetain(self.handle);
    }

    /// Releases this paragraph style reference.
    pub fn deinit(self: *ParagraphStyle) void {
        c.ImpellerParagraphStyleRelease(self.handle);
        self.handle = null;
    }

    /// Sets the paint used to fill glyphs.
    pub fn setForeground(self: ParagraphStyle, paint: Paint) void {
        c.ImpellerParagraphStyleSetForeground(self.handle, paint.handle);
    }

    /// Sets the paint used behind glyphs.
    pub fn setBackground(self: ParagraphStyle, paint: Paint) void {
        c.ImpellerParagraphStyleSetBackground(self.handle, paint.handle);
    }

    /// Sets the font weight used for glyph selection.
    pub fn setFontWeight(self: ParagraphStyle, weight: FontWeight) void {
        c.ImpellerParagraphStyleSetFontWeight(self.handle, weight);
    }

    /// Sets whether glyphs should be upright or italic.
    pub fn setFontStyle(self: ParagraphStyle, style: FontStyle) void {
        c.ImpellerParagraphStyleSetFontStyle(self.handle, style);
    }

    /// Sets the font family name.
    pub fn setFontFamily(self: ParagraphStyle, family_name: [*:0]const u8) void {
        c.ImpellerParagraphStyleSetFontFamily(self.handle, family_name);
    }

    /// Sets the font size in logical pixels.
    pub fn setFontSize(self: ParagraphStyle, size: f32) void {
        c.ImpellerParagraphStyleSetFontSize(self.handle, size);
    }

    /// Sets the line height multiplier.
    pub fn setHeight(self: ParagraphStyle, height: f32) void {
        c.ImpellerParagraphStyleSetHeight(self.handle, height);
    }

    /// Sets the horizontal text alignment.
    pub fn setTextAlignment(self: ParagraphStyle, text_align: TextAlignment) void {
        c.ImpellerParagraphStyleSetTextAlignment(self.handle, text_align);
    }

    /// Sets the text direction.
    pub fn setTextDirection(self: ParagraphStyle, direction: TextDirection) void {
        c.ImpellerParagraphStyleSetTextDirection(self.handle, direction);
    }

    /// Sets text decorations such as underline or strikethrough.
    pub fn setTextDecoration(self: ParagraphStyle, decoration: TextDecoration) void {
        var local_decoration = decoration;
        c.ImpellerParagraphStyleSetTextDecoration(self.handle, &local_decoration);
    }

    /// Limits the number of visible lines in the paragraph.
    pub fn setMaxLines(self: ParagraphStyle, max_lines: u32) void {
        c.ImpellerParagraphStyleSetMaxLines(self.handle, max_lines);
    }

    /// Sets the locale used during paragraph layout.
    pub fn setLocale(self: ParagraphStyle, locale: [*:0]const u8) void {
        c.ImpellerParagraphStyleSetLocale(self.handle, locale);
    }

    /// Sets the ellipsis string used when text is truncated.
    pub fn setEllipsis(self: ParagraphStyle, ellipsis: ?[*:0]const u8) void {
        c.ImpellerParagraphStyleSetEllipsis(self.handle, ellipsis);
    }
};

pub const ParagraphBuilder = struct {
    handle: c.ImpellerParagraphBuilder,

    /// Creates a paragraph builder associated with a typography context.
    pub fn init(context: TypographyContext) Error!ParagraphBuilder {
        const handle = c.ImpellerParagraphBuilderNew(context.handle) orelse return Error.CreateParagraphBuilderFailed;
        return .{ .handle = handle };
    }

    /// Retains this paragraph builder reference.
    pub fn retain(self: ParagraphBuilder) void {
        c.ImpellerParagraphBuilderRetain(self.handle);
    }

    /// Releases this paragraph builder reference.
    pub fn deinit(self: *ParagraphBuilder) void {
        c.ImpellerParagraphBuilderRelease(self.handle);
        self.handle = null;
    }

    /// Pushes a paragraph style onto the style stack.
    pub fn pushStyle(self: ParagraphBuilder, style: ParagraphStyle) void {
        c.ImpellerParagraphBuilderPushStyle(self.handle, style.handle);
    }

    /// Pops the current paragraph style from the style stack.
    pub fn popStyle(self: ParagraphBuilder) void {
        c.ImpellerParagraphBuilderPopStyle(self.handle);
    }

    /// Appends UTF-8 text using the current style.
    pub fn addText(self: ParagraphBuilder, text: []const u8) void {
        c.ImpellerParagraphBuilderAddText(self.handle, text.ptr, @intCast(text.len));
    }

    /// Lays out text within the specified width and returns an immutable paragraph.
    pub fn build(self: ParagraphBuilder, width: f32) Error!Paragraph {
        const handle = c.ImpellerParagraphBuilderBuildParagraphNew(self.handle, width) orelse return Error.CreateParagraphFailed;
        return .{ .handle = handle };
    }
};

pub const Paragraph = struct {
    handle: c.ImpellerParagraph,

    /// Retains this paragraph reference.
    pub fn retain(self: Paragraph) void {
        c.ImpellerParagraphRetain(self.handle);
    }

    /// Releases this paragraph reference.
    pub fn deinit(self: *Paragraph) void {
        c.ImpellerParagraphRelease(self.handle);
        self.handle = null;
    }

    /// Returns the layout width used for the paragraph.
    pub fn getMaxWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetMaxWidth(self.handle);
    }

    /// Returns the total paragraph height.
    pub fn getHeight(self: Paragraph) f32 {
        return c.ImpellerParagraphGetHeight(self.handle);
    }

    /// Returns the width of the longest visible line.
    pub fn getLongestLineWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetLongestLineWidth(self.handle);
    }

    /// Returns the actual width of the laid out paragraph.
    pub fn getMinIntrinsicWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetMinIntrinsicWidth(self.handle);
    }

    /// Returns the width needed without line breaking.
    pub fn getMaxIntrinsicWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetMaxIntrinsicWidth(self.handle);
    }

    /// Returns the ideographic baseline of the first line.
    pub fn getIdeographicBaseline(self: Paragraph) f32 {
        return c.ImpellerParagraphGetIdeographicBaseline(self.handle);
    }

    /// Returns the alphabetic baseline of the first line.
    pub fn getAlphabeticBaseline(self: Paragraph) f32 {
        return c.ImpellerParagraphGetAlphabeticBaseline(self.handle);
    }

    /// Returns the number of visible lines.
    pub fn getLineCount(self: Paragraph) u32 {
        return c.ImpellerParagraphGetLineCount(self.handle);
    }

    /// Returns the UTF-16 code unit range for the word at the given index.
    pub fn getWordBoundary(self: Paragraph, code_unit_index: usize) Range {
        var range: Range = undefined;
        c.ImpellerParagraphGetWordBoundary(self.handle, code_unit_index, &range);
        return range;
    }

    /// Returns cached line metrics for this paragraph.
    pub fn getLineMetrics(self: Paragraph) Error!LineMetrics {
        const handle = c.ImpellerParagraphGetLineMetrics(self.handle) orelse return Error.CreateLineMetricsFailed;
        return .{ .handle = handle };
    }

    /// Returns glyph information for the glyph nearest the UTF-16 code unit index.
    pub fn createGlyphInfoAtCodeUnitIndex(self: Paragraph, code_unit_index: usize) Error!GlyphInfo {
        const handle = c.ImpellerParagraphCreateGlyphInfoAtCodeUnitIndexNew(self.handle, code_unit_index) orelse return Error.CreateGlyphInfoFailed;
        return .{ .handle = handle };
    }

    /// Returns glyph information for the glyph nearest the given paragraph coordinates.
    pub fn createGlyphInfoAtParagraphCoordinates(self: Paragraph, x: f64, y: f64) Error!GlyphInfo {
        const handle = c.ImpellerParagraphCreateGlyphInfoAtParagraphCoordinatesNew(self.handle, x, y) orelse return Error.CreateGlyphInfoFailed;
        return .{ .handle = handle };
    }
};

pub const LineMetrics = struct {
    handle: c.ImpellerLineMetrics,

    /// Retains this line metrics reference.
    pub fn retain(self: LineMetrics) void {
        c.ImpellerLineMetricsRetain(self.handle);
    }

    /// Releases this line metrics reference.
    pub fn deinit(self: *LineMetrics) void {
        c.ImpellerLineMetricsRelease(self.handle);
        self.handle = null;
    }

    /// Returns the unscaled ascent for the specified line.
    pub fn getUnscaledAscent(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetUnscaledAscent(self.handle, line);
    }

    /// Returns the ascent for the specified line.
    pub fn getAscent(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetAscent(self.handle, line);
    }

    /// Returns the descent for the specified line.
    pub fn getDescent(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetDescent(self.handle, line);
    }

    /// Returns the baseline y coordinate for the specified line.
    pub fn getBaseline(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetBaseline(self.handle, line);
    }

    /// Returns whether the specified line ends with an explicit hard break.
    pub fn isHardbreak(self: LineMetrics, line: usize) bool {
        return c.ImpellerLineMetricsIsHardbreak(self.handle, line);
    }

    /// Returns the width of the specified line.
    pub fn getWidth(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetWidth(self.handle, line);
    }

    /// Returns the height of the specified line.
    pub fn getHeight(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetHeight(self.handle, line);
    }

    /// Returns the left edge x coordinate of the specified line.
    pub fn getLeft(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetLeft(self.handle, line);
    }

    /// Returns the UTF-16 start index of the specified line.
    pub fn getCodeUnitStartIndex(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitStartIndex(self.handle, line);
    }

    /// Returns the UTF-16 end index of the specified line.
    pub fn getCodeUnitEndIndex(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitEndIndex(self.handle, line);
    }

    /// Returns the UTF-16 end index of the specified line excluding trailing whitespace.
    pub fn getCodeUnitEndIndexExcludingWhitespace(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitEndIndexExcludingWhitespace(self.handle, line);
    }

    /// Returns the UTF-16 end index of the specified line including a trailing newline.
    pub fn getCodeUnitEndIndexIncludingNewline(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitEndIndexIncludingNewline(self.handle, line);
    }
};

pub const GlyphInfo = struct {
    handle: c.ImpellerGlyphInfo,

    /// Retains this glyph info reference.
    pub fn retain(self: GlyphInfo) void {
        c.ImpellerGlyphInfoRetain(self.handle);
    }

    /// Releases this glyph info reference.
    pub fn deinit(self: *GlyphInfo) void {
        c.ImpellerGlyphInfoRelease(self.handle);
        self.handle = null;
    }

    /// Returns the UTF-16 start index of the grapheme cluster.
    pub fn getGraphemeClusterCodeUnitRangeBegin(self: GlyphInfo) usize {
        return c.ImpellerGlyphInfoGetGraphemeClusterCodeUnitRangeBegin(self.handle);
    }

    /// Returns the UTF-16 end index of the grapheme cluster.
    pub fn getGraphemeClusterCodeUnitRangeEnd(self: GlyphInfo) usize {
        return c.ImpellerGlyphInfoGetGraphemeClusterCodeUnitRangeEnd(self.handle);
    }

    /// Returns the grapheme cluster bounds in paragraph coordinates.
    pub fn getGraphemeClusterBounds(self: GlyphInfo) Rect {
        var bounds: Rect = undefined;
        c.ImpellerGlyphInfoGetGraphemeClusterBounds(self.handle, &bounds);
        return bounds;
    }

    /// Returns whether this glyph info refers to an ellipsis glyph.
    pub fn isEllipsis(self: GlyphInfo) bool {
        return c.ImpellerGlyphInfoIsEllipsis(self.handle);
    }

    /// Returns the direction of the run containing this glyph.
    pub fn getTextDirection(self: GlyphInfo) TextDirection {
        return c.ImpellerGlyphInfoGetTextDirection(self.handle);
    }
};
