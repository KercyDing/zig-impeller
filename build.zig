const std = @import("std");

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    platform: Platform,
};

const Platform = enum {
    linux,
    macos,
    windows,
};

const LinuxGlfwPlatform = enum {
    auto,
    x11,
    wayland,
};

const ImpellerSdk = struct {
    header: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    lib_path: std.Build.LazyPath,
    lib_path_string: []const u8,
    library: std.Build.LazyPath,
    import_library: ?std.Build.LazyPath,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options: BuildOptions = .{
        .target = target,
        .optimize = optimize,
        .platform = b.option(Platform, "platform", "Example platform to build (linux, macos, windows)") orelse defaultPlatform(b.graph.host.result.os.tag),
    };

    const sdk = resolveImpellerSdk(b, target.result);
    const mod = addModule(b, options, sdk);

    addLibraryArtifact(b, mod);
    addTests(b, options, sdk, mod);
    addExampleStep(b, options, sdk, mod);
}

fn addLibraryArtifact(b: *std.Build, mod: *std.Build.Module) void {
    const lib = b.addLibrary(.{
        .name = "impeller",
        .root_module = mod,
    });
    b.installArtifact(lib);
}

fn addExampleStep(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) void {
    const examples_step = b.step("examples", "Run the selected GLFW example");
    const example = addExample(b, options, sdk, mod) orelse return;
    const run_example = b.addRunArtifact(example);
    configureImpellerRuntime(run_example, sdk);
    examples_step.dependOn(&run_example.step);
}

fn addModule(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk) *std.Build.Module {
    const impeller_c = addImpellerBindings(b, options, sdk);
    const mod = b.addModule("impeller", .{
        .root_source_file = b.path("src/impeller.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller_c", .module = impeller_c },
        },
    });
    configureImpeller(mod, sdk);
    linkImpeller(mod, sdk, options.target.result);
    return mod;
}

fn addTests(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/impeller_test.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
        },
    });
    configureImpeller(test_mod, sdk);

    const tests = b.addTest(.{
        .root_module = test_mod,
        .use_llvm = true,
        .use_lld = true,
    });

    const run_tests = b.addRunArtifact(tests);
    configureImpellerRuntime(run_tests, sdk);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn addExample(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) ?*std.Build.Step.Compile {
    return switch (options.platform) {
        .macos => addMacosGlfwExample(b, options, sdk, mod),
        .linux => addLinuxGlfwExample(b, options, sdk, mod),
        .windows => addWindowsGlfwExample(b, options, sdk, mod),
    };
}

fn addMacosGlfwExample(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) ?*std.Build.Step.Compile {
    if (options.target.result.os.tag != .macos) {
        @panic("-Dexample=macos requires a macOS target");
    }

    const glfw_dep = b.lazyDependency("glfw_zig", .{
        .target = options.target,
        .optimize = options.optimize,
    }) orelse return null;
    const glfw_lib = glfw_dep.artifact("glfw");
    const glfw_c = addGlfwBindings(b, options, glfw_dep, glfw_lib, .macos);

    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/macos/macos_glfw.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
            .{ .name = "common_draw", .module = addCommonDrawModule(b, options, sdk, mod) },
            .{ .name = "glfw_c", .module = glfw_c },
        },
    });
    configureImpeller(example_mod, sdk);
    example_mod.addCSourceFile(.{
        .file = b.path("examples/macos/macos_glfw_metal.m"),
        .flags = &.{ "-fobjc-arc", "-Wno-deprecated-declarations", "-Wno-unguarded-availability-new" },
        .language = .objective_c,
    });
    example_mod.linkFramework("AppKit", .{});
    example_mod.linkFramework("Metal", .{});
    example_mod.linkFramework("QuartzCore", .{});

    const example = b.addExecutable(.{
        .name = "macos-glfw",
        .root_module = example_mod,
    });
    example.root_module.linkLibrary(glfw_lib);
    return example;
}

fn addLinuxGlfwExample(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) ?*std.Build.Step.Compile {
    if (options.target.result.os.tag != .linux or options.target.result.cpu.arch != .x86_64) {
        @panic("-Dexample=linux requires a linux x86_64 target");
    }

    const glfw_platform = b.option(LinuxGlfwPlatform, "glfw", "GLFW platform for the Linux desktop example (auto, x11, wayland)") orelse .auto;
    const glfw_dep = b.lazyDependency("glfw_zig", .{
        .target = options.target,
        .optimize = options.optimize,
    }) orelse return null;
    const glfw_lib = glfw_dep.artifact("glfw");
    const glfw_c = addGlfwBindings(b, options, glfw_dep, glfw_lib, .linux);
    const linux_example_options = b.addOptions();
    linux_example_options.addOption(LinuxGlfwPlatform, "glfw", glfw_platform);

    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/linux/linux_glfw.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
            .{ .name = "common_draw", .module = addCommonDrawModule(b, options, sdk, mod) },
            .{ .name = "glfw_c", .module = glfw_c },
            .{ .name = "build_options", .module = linux_example_options.createModule() },
        },
    });
    configureImpeller(example_mod, sdk);

    const example = b.addExecutable(.{
        .name = "linux-glfw",
        .root_module = example_mod,
        .use_llvm = true,
        .use_lld = true,
    });
    example.root_module.linkLibrary(glfw_lib);
    linkLinuxVulkanExample(example);
    return example;
}

/// Builds the GLFW + Vulkan example targeting Windows desktop.
/// Reuses the Vulkan-backed Impeller swapchain pipeline from the Linux example;
/// no Vulkan loader linking is required because GLFW dynamically loads
/// `vulkan-1.dll` at runtime via `glfwGetInstanceProcAddress`.
fn addWindowsGlfwExample(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) ?*std.Build.Step.Compile {
    if (options.target.result.os.tag != .windows) {
        @panic("-Dexample=windows requires a windows target");
    }
    if (options.target.result.cpu.arch != .x86_64 and options.target.result.cpu.arch != .aarch64) {
        @panic("-Dexample=windows requires an x86_64 or aarch64 target");
    }

    const glfw_dep = b.lazyDependency("glfw_zig", .{
        .target = options.target,
        .optimize = options.optimize,
    }) orelse return null;
    const glfw_lib = glfw_dep.artifact("glfw");
    const glfw_c = addGlfwBindings(b, options, glfw_dep, glfw_lib, .windows);

    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/windows/windows_glfw.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
            .{ .name = "common_draw", .module = addCommonDrawModule(b, options, sdk, mod) },
            .{ .name = "glfw_c", .module = glfw_c },
        },
    });
    configureImpeller(example_mod, sdk);

    const example = b.addExecutable(.{
        .name = "windows-glfw",
        .root_module = example_mod,
        .use_llvm = true,
        .use_lld = true,
    });
    example.root_module.linkLibrary(glfw_lib);
    installImpellerRuntimeDll(b, sdk, options.target.result);
    return example;
}

fn defaultPlatform(os_tag: std.Target.Os.Tag) Platform {
    return switch (os_tag) {
        .macos => .macos,
        .windows => .windows,
        else => .linux,
    };
}

fn addCommonDrawModule(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) *std.Build.Module {
    const draw_mod = b.createModule(.{
        .root_source_file = b.path("examples/common/draw.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
        },
    });
    configureImpeller(draw_mod, sdk);
    return draw_mod;
}

fn addImpellerBindings(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk) *std.Build.Module {
    const translate = b.addTranslateC(.{
        .root_source_file = sdk.header,
        .target = options.target,
        .optimize = options.optimize,
    });
    translate.addIncludePath(sdk.include_path);
    return translate.createModule();
}

fn addGlfwBindings(
    b: *std.Build,
    options: BuildOptions,
    glfw_dep: *std.Build.Dependency,
    glfw_lib: *std.Build.Step.Compile,
    platform: Platform,
) *std.Build.Module {
    const translate = b.addTranslateC(.{
        .root_source_file = glfw_dep.path("glfw/include/GLFW/glfw3.h"),
        .target = options.target,
        .optimize = options.optimize,
    });
    if (platform == .linux or platform == .windows) {
        translate.defineCMacro("GLFW_INCLUDE_VULKAN", null);
        // GLFW's installed header tree includes the bundled Vulkan headers
        // (via the vulkan_zig dependency), so translate-c can resolve
        // `<vulkan/vulkan.h>` without relying on system include paths.
        translate.addIncludePath(glfw_lib.getEmittedIncludeTree());
    }
    return translate.createModule();
}

fn linkLinuxVulkanExample(exe: *std.Build.Step.Compile) void {
    exe.root_module.linkSystemLibrary("vulkan", .{});
    exe.root_module.linkSystemLibrary("dl", .{});
    exe.root_module.linkSystemLibrary("pthread", .{});
    exe.root_module.linkSystemLibrary("m", .{});
}

fn configureImpeller(module: *std.Build.Module, sdk: ImpellerSdk) void {
    module.addIncludePath(sdk.include_path);
    module.addRPath(sdk.lib_path);
}

fn linkImpeller(module: *std.Build.Module, sdk: ImpellerSdk, target: std.Target) void {
    if (target.os.tag == .windows) {
        module.addObjectFile(sdk.import_library.?);
    } else {
        module.addObjectFile(sdk.library);
    }
}

fn configureImpellerRuntime(run: *std.Build.Step.Run, sdk: ImpellerSdk) void {
    run.setEnvironmentVariable("DYLD_LIBRARY_PATH", sdk.lib_path_string);
    run.setEnvironmentVariable("LD_LIBRARY_PATH", sdk.lib_path_string);
    // Windows resolves DLLs via the executable directory and PATH; the DLL is
    // installed alongside the executable (see installImpellerRuntimeDll), but
    // we also extend PATH so child processes locate the runtime as well.
    run.addPathDir(sdk.lib_path_string);
}

/// Installs `impeller.dll` next to the executable so Windows runs can locate
/// it through the standard PE search order. No-op on non-Windows targets.
fn installImpellerRuntimeDll(b: *std.Build, sdk: ImpellerSdk, target: std.Target) void {
    if (target.os.tag != .windows) return;
    const install = b.addInstallBinFile(sdk.library, "impeller.dll");
    b.getInstallStep().dependOn(&install.step);
}

fn resolveImpellerSdk(b: *std.Build, target: std.Target) ImpellerSdk {
    const include_path = b.path("vendor/impeller/include");
    const os_dir = impellerLibOsDir(target) orelse @panic("unsupported Impeller SDK target");
    const arch_dir = impellerLibArchDir(target) orelse @panic("unsupported Impeller SDK target architecture");
    const lib_path = b.fmt("vendor/impeller/lib/{s}/{s}", .{ os_dir, arch_dir });
    return .{
        .header = b.path("vendor/impeller/include/impeller.h"),
        .include_path = include_path,
        .lib_path = b.path(lib_path),
        .lib_path_string = b.pathFromRoot(lib_path),
        .library = b.path(b.fmt("{s}/{s}", .{ lib_path, impellerLibraryName(target) })),
        .import_library = if (target.os.tag == .windows)
            b.path(b.fmt("{s}/{s}", .{ lib_path, impellerImportLibraryName() }))
        else
            null,
    };
}

fn impellerLibraryName(target: std.Target) []const u8 {
    return switch (target.os.tag) {
        .macos => "libimpeller.dylib",
        .windows => "impeller.dll",
        else => "libimpeller.so",
    };
}

fn impellerImportLibraryName() []const u8 {
    return "impeller.dll.lib";
}

fn impellerLibOsDir(target: std.Target) ?[]const u8 {
    return switch (target.os.tag) {
        .macos => "macos",
        .linux => "linux",
        .windows => "windows",
        else => null,
    };
}

fn impellerLibArchDir(target: std.Target) ?[]const u8 {
    return switch (target.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x64",
        else => null,
    };
}
