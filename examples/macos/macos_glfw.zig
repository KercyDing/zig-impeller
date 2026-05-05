const std = @import("std");
const impeller = @import("impeller");
const glfw = @import("glfw_c");

extern fn macosGlfwAttachMetalLayer(nsview: ?*anyopaque) ?*anyopaque;
extern fn macosGlfwAcquireNextDrawable(layer: ?*anyopaque, width: f64, height: f64) ?*anyopaque;
extern fn macosGlfwReleaseDrawable(drawable: ?*anyopaque) void;

/// Returns the underlying NSView for a GLFW window. Declared here because
/// `glfw3native.h` pulls Carbon SDK headers that translate-c cannot parse.
extern fn glfwGetCocoaView(window: ?*glfw.GLFWwindow) ?*anyopaque;

const ExampleError = error{
    GlfwInitFailed,
    WindowCreateFailed,
    MetalLayerAttachFailed,
};

pub fn main() !void {
    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);

    if (glfw.glfwInit() != glfw.GLFW_TRUE) {
        return ExampleError.GlfwInitFailed;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    glfw.glfwWindowHint(glfw.GLFW_COCOA_RETINA_FRAMEBUFFER, glfw.GLFW_TRUE);
    const window = glfw.glfwCreateWindow(800, 600, "zig-impeller Metal", null, null) orelse {
        return ExampleError.WindowCreateFailed;
    };
    defer glfw.glfwDestroyWindow(window);

    const ns_view: ?*anyopaque = glfwGetCocoaView(window);
    const metal_layer = macosGlfwAttachMetalLayer(ns_view) orelse return ExampleError.MetalLayerAttachFailed;

    var context = try impeller.Context.initMetal();
    defer context.deinit();

    const font_bytes = try loadFontBytes();

    var texture_bytes = [_]u8{
        255, 0, 0, 255, 255, 255, 0, 255, 0, 255, 0, 255, 0, 0, 0, 255,
        255, 255, 255, 255, 255, 0, 255, 255, 0, 255, 255, 255, 255, 128, 0, 255,
        64, 64, 255, 255, 255, 64, 64, 255, 64, 255, 64, 255, 32, 32, 32, 255,
        0, 0, 255, 255, 255, 0, 128, 255, 0, 128, 255, 255, 255, 255, 255, 255,
    };
    var checker_texture = try impeller.Texture.initWithContents(
        context,
        impeller.textureDescriptor(
            impeller.pixel_formats.rgba8888,
            impeller.pixelSize(4, 4),
            1,
        ),
        impeller.mapping(texture_bytes[0..]),
    );
    defer checker_texture.deinit();
    checker_texture.retain();
    defer checker_texture.deinit();

    var display_list = try createDisplayList(checker_texture, font_bytes);
    defer display_list.deinit();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();

        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        var fb_width: c_int = 0;
        var fb_height: c_int = 0;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);

        const drawable = macosGlfwAcquireNextDrawable(
            metal_layer,
            @as(f64, @floatFromInt(fb_width)),
            @as(f64, @floatFromInt(fb_height)),
        ) orelse continue;
        defer macosGlfwReleaseDrawable(drawable);

        var surface = try impeller.Surface.wrapMetalDrawable(context, drawable);
        defer surface.deinit();

        try surface.draw(display_list);
        try surface.present();
    }
}

fn loadFontBytes() ![]const u8 {
    const font_path = "examples/fonts/NotoSans-Regular.ttf";
    const io = std.Options.debug_io;
    return try std.Io.Dir.cwd().readFileAlloc(io, font_path, std.heap.page_allocator, .limited(std.math.maxInt(usize)));
}

fn createDisplayList(checker_texture: impeller.Texture, font_bytes: []const u8) !impeller.DisplayList {
    var builder = try impeller.DisplayListBuilder.init(null);
    defer builder.deinit();

    var paint = try impeller.Paint.init();
    defer paint.deinit();

    var blur = try impeller.ImageFilter.initBlur(10.0, 10.0, impeller.tile_modes.decal);
    defer blur.deinit();

    var dilate_image_filter = try impeller.ImageFilter.initDilate(4.0, 4.0);
    defer dilate_image_filter.deinit();

    var erode_image_filter = try impeller.ImageFilter.initErode(3.0, 3.0);
    defer erode_image_filter.deinit();

    var matrix_image_filter = try impeller.ImageFilter.initMatrix(
        translationMatrix(18.0, 0.0),
        impeller.texture_samplings.linear,
    );
    defer matrix_image_filter.deinit();
    matrix_image_filter.retain();
    defer matrix_image_filter.deinit();

    var composed_image_filter = try impeller.ImageFilter.initCompose(dilate_image_filter, erode_image_filter);
    defer composed_image_filter.deinit();

    var blend_color_filter = try impeller.ColorFilter.initBlend(
        impeller.srgb(1.0, 0.0, 1.0, 0.55),
        impeller.blend_modes.source_atop,
    );
    defer blend_color_filter.deinit();
    blend_color_filter.retain();
    defer blend_color_filter.deinit();

    var grayscale_color_filter = try impeller.ColorFilter.initColorMatrix(impeller.colorMatrix(.{
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
    }));
    defer grayscale_color_filter.deinit();

    var blur_mask_filter = try impeller.MaskFilter.initBlur(impeller.blur_styles.normal, 12.0);
    defer blur_mask_filter.deinit();
    blur_mask_filter.retain();
    defer blur_mask_filter.deinit();

    var reused_display_list = try createReusableDisplayList();
    defer reused_display_list.deinit();

    var typography_context = try impeller.TypographyContext.init();
    defer typography_context.deinit();
    try typography_context.registerFont(impeller.mapping(font_bytes), "Noto Sans");

    var paragraph_foreground = try impeller.Paint.init();
    defer paragraph_foreground.deinit();
    paragraph_foreground.setColor(impeller.srgb(0.12, 0.12, 0.12, 1.0));

    var paragraph_style = try impeller.ParagraphStyle.init();
    defer paragraph_style.deinit();
    paragraph_style.setForeground(paragraph_foreground);
    paragraph_style.setFontFamily("Noto Sans");
    paragraph_style.setFontSize(18.0);
    paragraph_style.setFontWeight(impeller.font_weights.bold);
    paragraph_style.setTextAlignment(impeller.text_alignments.left);
    paragraph_style.setTextDirection(impeller.text_directions.ltr);
    paragraph_style.setHeight(1.1);
    paragraph_style.setMaxLines(2);
    paragraph_style.setEllipsis("...");

    var paragraph_builder = try impeller.ParagraphBuilder.init(typography_context);
    defer paragraph_builder.deinit();
    paragraph_builder.pushStyle(paragraph_style);
    paragraph_builder.addText("Impeller paragraph");
    paragraph_builder.addText(" wraps on macOS.");
    paragraph_builder.popStyle();

    var paragraph = try paragraph_builder.build(170.0);
    defer paragraph.deinit();

    var triangle_builder = try impeller.PathBuilder.init();
    defer triangle_builder.deinit();

    triangle_builder.moveTo(impeller.point(500.0, 250.0));
    triangle_builder.lineTo(impeller.point(535.0, 310.0));
    triangle_builder.lineTo(impeller.point(465.0, 310.0));
    triangle_builder.close();
    var triangle_path = try triangle_builder.takePath(impeller.fill_types.non_zero);
    defer triangle_path.deinit();

    var oval_builder = try impeller.PathBuilder.init();
    defer oval_builder.deinit();

    oval_builder.addOval(impeller.rect(630.0, 226.0, 72.0, 72.0));
    var oval_path = try oval_builder.takePath(impeller.fill_types.non_zero);
    defer oval_path.deinit();

    var quadratic_builder = try impeller.PathBuilder.init();
    defer quadratic_builder.deinit();

    quadratic_builder.moveTo(impeller.point(52.0, 360.0));
    quadratic_builder.quadraticCurveTo(impeller.point(95.0, 308.0), impeller.point(138.0, 360.0));
    var quadratic_path = try quadratic_builder.takePath(impeller.fill_types.non_zero);
    defer quadratic_path.deinit();

    var cubic_builder = try impeller.PathBuilder.init();
    defer cubic_builder.deinit();

    cubic_builder.moveTo(impeller.point(170.0, 360.0));
    cubic_builder.cubicCurveTo(
        impeller.point(200.0, 300.0),
        impeller.point(250.0, 420.0),
        impeller.point(282.0, 360.0),
    );
    var cubic_path = try cubic_builder.takePath(impeller.fill_types.non_zero);
    defer cubic_path.deinit();

    var arc_builder = try impeller.PathBuilder.init();
    defer arc_builder.deinit();

    arc_builder.addArc(impeller.rect(330.0, 320.0, 72.0, 72.0), 25.0, 320.0);
    var arc_path = try arc_builder.takePath(impeller.fill_types.non_zero);
    defer arc_path.deinit();

    var rounded_rect_path_builder = try impeller.PathBuilder.init();
    defer rounded_rect_path_builder.deinit();

    rounded_rect_path_builder.addRoundedRect(
        impeller.rect(430.0, 324.0, 92.0, 64.0),
        impeller.uniformRadii(20.0),
    );
    var rounded_rect_path = try rounded_rect_path_builder.takePath(impeller.fill_types.non_zero);
    defer rounded_rect_path.deinit();

    paint.setColor(impeller.srgb(1.0, 1.0, 1.0, 1.0));
    builder.drawPaint(paint);

    paint.setColor(impeller.srgb(1.0, 0.0, 0.0, 1.0));
    builder.save();
    builder.clipRect(
        impeller.rect(20, 20, 60, 100),
        impeller.clip_operations.intersect,
    );
    builder.drawRect(impeller.rect(20, 20, 100, 100), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.05, 0.65, 0.95, 1.0));
    builder.save();
    builder.clipOval(
        impeller.rect(96.0, 18.0, 72.0, 72.0),
        impeller.clip_operations.intersect,
    );
    builder.drawRect(impeller.rect(88.0, 10.0, 88.0, 88.0), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.95, 0.6, 0.15, 1.0));
    builder.save();
    builder.clipRoundedRect(
        impeller.rect(180.0, 20.0, 92.0, 72.0),
        impeller.uniformRadii(18.0),
        impeller.clip_operations.intersect,
    );
    builder.drawRect(impeller.rect(168.0, 8.0, 116.0, 96.0), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.9, 0.25, 0.55, 1.0));
    builder.save();
    builder.clipPath(triangle_path, impeller.clip_operations.intersect);
    builder.drawRect(impeller.rect(450.0, 236.0, 92.0, 92.0), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.0, 0.2, 1.0, 1.0));
    builder.save();
    builder.translate(220, 120);
    builder.rotate(45.0);
    builder.drawRect(impeller.rect(-40, -40, 80, 80), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.0, 0.7, 0.2, 1.0));
    builder.save();
    builder.translate(360, 120);
    builder.scale(1.6, 0.6);
    builder.drawRect(impeller.rect(-40, -40, 80, 80), paint);
    builder.restore();

    const layer_base_count = builder.getSaveCount();
    builder.save();
    builder.translate(520, 80);
    const layer_count = builder.getSaveCount();
    builder.saveLayer(
        impeller.rect(-10, -10, 140, 140),
        null,
        blur,
    );

    paint.setColor(impeller.srgb(0.1, 0.1, 0.1, 0.35));
    builder.drawRect(impeller.rect(24, 24, 72, 72), paint);

    paint.setColor(impeller.srgb(1.0, 0.7, 0.0, 1.0));
    builder.drawRect(impeller.rect(0, 0, 72, 72), paint);

    builder.restoreToCount(layer_count);
    builder.restoreToCount(layer_base_count);

    builder.save();
    builder.setTransform(translationMatrix(680.0, 120.0));
    paint.setColor(impeller.srgb(0.6, 0.0, 0.8, 1.0));
    builder.drawRect(impeller.rect(-24, -24, 48, 48), paint);

    const translated_matrix = builder.getTransform();
    builder.transform(scaleMatrix(1.0, 1.8));
    paint.setColor(impeller.srgb(1.0, 0.0, 1.0, 0.45));
    builder.drawRect(impeller.rect(-24, -24, 48, 48), paint);

    builder.setTransform(translated_matrix);
    builder.resetTransform();
    paint.setColor(impeller.srgb(0.0, 0.7, 0.9, 1.0));
    builder.drawRect(impeller.rect(650, 180, 60, 24), paint);
    builder.restore();

    paint.setColor(impeller.srgb(0.95, 0.4, 0.1, 1.0));
    builder.drawOval(impeller.rect(40, 220, 90, 60), paint);

    paint.setColor(impeller.srgb(0.45, 0.2, 0.9, 1.0));
    builder.drawRoundedRect(
        impeller.rect(170, 220, 110, 60),
        impeller.uniformRadii(18.0),
        paint,
    );

    paint.setColor(impeller.srgb(0.9, 0.15, 0.2, 1.0));
    builder.drawPath(triangle_path, paint);

    paint.setColor(impeller.srgb(0.1, 0.1, 0.1, 1.0));
    builder.drawRoundedRectDifference(
        impeller.rect(320, 214, 124, 72),
        impeller.uniformRadii(22.0),
        impeller.rect(344, 232, 76, 36),
        impeller.uniformRadii(10.0),
        paint,
    );

    paint.setColor(impeller.srgb(0.1, 0.55, 0.95, 1.0));
    builder.drawPath(oval_path, paint);

    paint.setColor(impeller.srgb(0.95, 0.45, 0.2, 1.0));
    builder.drawPath(quadratic_path, paint);

    paint.setColor(impeller.srgb(0.2, 0.8, 0.45, 1.0));
    builder.drawPath(cubic_path, paint);

    paint.setColor(impeller.srgb(0.65, 0.3, 0.95, 1.0));
    builder.drawPath(arc_path, paint);

    paint.setColor(impeller.srgb(0.1, 0.7, 0.7, 1.0));
    builder.drawPath(rounded_rect_path, paint);

    builder.save();
    builder.translate(560.0, 330.0);
    builder.drawDisplayList(reused_display_list, 1.0);
    builder.translate(88.0, 0.0);
    builder.drawDisplayList(reused_display_list, 0.45);
    builder.restore();

    paint.setColor(impeller.srgb(0.25, 0.55, 0.95, 1.0));
    builder.drawRoundedRect(
        impeller.rect(40.0, 430.0, 100.0, 56.0),
        impeller.uniformRadii(16.0),
        paint,
    );

    paint.setColorFilter(blend_color_filter);
    builder.drawRoundedRect(
        impeller.rect(170.0, 430.0, 100.0, 56.0),
        impeller.uniformRadii(16.0),
        paint,
    );

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(1.0, 0.75, 0.2, 1.0));
    paint.setColorFilter(grayscale_color_filter);
    builder.drawRoundedRect(
        impeller.rect(300.0, 430.0, 100.0, 56.0),
        impeller.uniformRadii(16.0),
        paint,
    );

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(0.9, 0.15, 0.15, 1.0));
    paint.setMaskFilter(blur_mask_filter);
    builder.drawPath(triangle_path, paint);

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(0.15, 0.75, 0.9, 1.0));
    paint.setImageFilter(matrix_image_filter);
    builder.drawRoundedRectDifference(
        impeller.rect(430.0, 430.0, 100.0, 56.0),
        impeller.uniformRadii(16.0),
        impeller.rect(448.0, 438.0, 28.0, 18.0),
        impeller.uniformRadii(6.0),
        paint,
    );

    const gradient_colors = [_]impeller.Color{
        impeller.srgb(1.0, 0.25, 0.25, 1.0),
        impeller.srgb(1.0, 0.95, 0.2, 1.0),
        impeller.srgb(0.2, 0.75, 1.0, 1.0),
    };
    const gradient_stops = [_]f32{ 0.0, 0.5, 1.0 };
    var linear_gradient = try impeller.ColorSource.initLinearGradient(
        impeller.point(40.0, 520.0),
        impeller.point(140.0, 576.0),
        gradient_colors[0..],
        gradient_stops[0..],
        impeller.tile_modes.clamp,
        null,
    );
    defer linear_gradient.deinit();
    linear_gradient.retain();
    defer linear_gradient.deinit();

    var radial_gradient = try impeller.ColorSource.initRadialGradient(
        impeller.point(230.0, 548.0),
        52.0,
        gradient_colors[0..],
        gradient_stops[0..],
        impeller.tile_modes.clamp,
        null,
    );
    defer radial_gradient.deinit();

    var image_color_source = try impeller.ColorSource.initImage(
        checker_texture,
        impeller.tile_modes.repeat,
        impeller.tile_modes.repeat,
        impeller.texture_samplings.nearest_neighbor,
        scaleMatrix(6.0, 6.0),
    );
    defer image_color_source.deinit();

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColorSource(linear_gradient);
    builder.drawRoundedRect(
        impeller.rect(40.0, 520.0, 100.0, 56.0),
        impeller.uniformRadii(16.0),
        paint,
    );

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColorSource(radial_gradient);
    builder.drawOval(impeller.rect(180.0, 516.0, 100.0, 64.0), paint);

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColorSource(image_color_source);
    builder.drawRoundedRect(
        impeller.rect(320.0, 520.0, 120.0, 56.0),
        impeller.uniformRadii(16.0),
        paint,
    );

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(0.08, 0.08, 0.08, 1.0));
    paint.setDrawStyle(impeller.draw_styles.stroke);
    paint.setStrokeWidth(14.0);
    paint.setStrokeCap(impeller.stroke_caps.round);
    paint.setStrokeJoin(impeller.stroke_joins.round);
    paint.setStrokeMiter(2.0);
    builder.drawPath(arc_path, paint);

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(0.18, 0.18, 0.18, 1.0));
    paint.setDrawStyle(impeller.draw_styles.stroke);
    paint.setStrokeWidth(8.0);
    paint.setStrokeCap(impeller.stroke_caps.round);
    builder.drawLine(
        impeller.point(470.0, 520.0),
        impeller.point(560.0, 560.0),
        paint,
    );

    paint.setColor(impeller.srgb(0.95, 0.3, 0.2, 1.0));
    builder.drawDashedLine(
        impeller.point(470.0, 560.0),
        impeller.point(560.0, 520.0),
        12.0,
        8.0,
        paint,
    );

    builder.drawShadow(
        rounded_rect_path,
        impeller.srgb(0.05, 0.1, 0.2, 0.45),
        18.0,
        false,
        1.0,
    );

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(0.92, 0.95, 1.0, 1.0));
    builder.drawRoundedRect(
        impeller.rect(580.0, 508.0, 190.0, 78.0),
        impeller.uniformRadii(14.0),
        paint,
    );
    builder.drawParagraph(paragraph, impeller.point(592.0, 522.0));

    paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColor(impeller.srgb(1.0, 1.0, 1.0, 1.0));
    builder.drawTextureRect(
        checker_texture,
        impeller.rect(0.0, 0.0, 4.0, 4.0),
        impeller.rect(688.0, 424.0, 72.0, 72.0),
        impeller.texture_samplings.nearest_neighbor,
        paint,
    );

    return builder.build();
}

fn createReusableDisplayList() !impeller.DisplayList {
    var builder = try impeller.DisplayListBuilder.init(null);
    defer builder.deinit();

    var paint = try impeller.Paint.init();
    defer paint.deinit();

    paint.setColor(impeller.srgb(0.95, 0.8, 0.15, 1.0));
    builder.drawRoundedRect(
        impeller.rect(0.0, 0.0, 52.0, 52.0),
        impeller.uniformRadii(14.0),
        paint,
    );

    paint.setColor(impeller.srgb(0.75, 0.2, 0.15, 1.0));
    builder.drawRect(impeller.rect(18.0, 8.0, 16.0, 36.0), paint);
    builder.drawRect(impeller.rect(8.0, 18.0, 36.0, 16.0), paint);

    return builder.build();
}

fn translationMatrix(x: f32, y: f32) impeller.Matrix {
    return .{
        .m = .{
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            x, y, 0.0, 1.0,
        },
    };
}

fn scaleMatrix(x: f32, y: f32) impeller.Matrix {
    return .{
        .m = .{
            x, 0.0, 0.0, 0.0,
            0.0, y, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        },
    };
}

fn glfwErrorCallback(code: c_int, description: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW Error ({d}): {s}\n", .{ code, std.mem.span(description) });
}
