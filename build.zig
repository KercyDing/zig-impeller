const std = @import("std");

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    example: Example,
};

const Example = enum {
    linux,
    macos,
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
    const options: BuildOptions = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .example = b.option(Example, "example", "Example to build for the current target platform (linux, macos)") orelse defaultExample(b.graph.host.result.os.tag),
    };
    const sdk = resolveImpellerSdk(b, options.target.result);
    const mod = addModule(b, options, sdk);

    const example = addExample(b, options, sdk, mod);
    b.installArtifact(example);

    const run_example = b.addRunArtifact(example);
    run_example.step.dependOn(b.getInstallStep());
    configureImpellerRuntime(run_example, sdk);

    const run_step = b.step("run", "Run the selected example for the current target platform");
    run_step.dependOn(&run_example.step);
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
    return mod;
}

fn addExample(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) *std.Build.Step.Compile {
    return switch (options.example) {
        .macos => addMacosGlfwExample(b, options, sdk, mod),
        .linux => addLinuxGlfwExample(b, options, sdk, mod),
    };
}

fn addMacosGlfwExample(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) *std.Build.Step.Compile {
    if (options.target.result.os.tag != .macos) {
        @panic("-Dexample=macos requires a macOS target");
    }

    const glfw_dep = b.dependency("glfw_zig", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    const glfw_c = addGlfwBindings(b, options, glfw_dep, .macos);
    const glfw_lib = glfw_dep.artifact("glfw");

    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/macos/macos_glfw.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
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
    linkImpeller(example.root_module, sdk, options.target.result);
    return example;
}

fn addLinuxGlfwExample(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) *std.Build.Step.Compile {
    if (options.target.result.os.tag != .linux or options.target.result.cpu.arch != .x86_64) {
        @panic("-Dexample=linux requires a linux x86_64 target");
    }

    const glfw_platform = b.option(LinuxGlfwPlatform, "glfw", "GLFW platform for the Linux desktop example (auto, x11, wayland)") orelse .auto;
    const glfw_dep = b.dependency("glfw_zig", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    const glfw_c = addGlfwBindings(b, options, glfw_dep, .linux);
    const glfw_lib = glfw_dep.artifact("glfw");
    const linux_example_options = b.addOptions();
    linux_example_options.addOption(LinuxGlfwPlatform, "glfw", glfw_platform);

    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/linux/linux_glfw.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
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
    linkVulkanExample(example);
    linkImpeller(example.root_module, sdk, options.target.result);
    return example;
}

fn defaultExample(os_tag: std.Target.Os.Tag) Example {
    return switch (os_tag) {
        .macos => .macos,
        else => .linux,
    };
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
    platform: Example,
) *std.Build.Module {
    const translate = b.addTranslateC(.{
        .root_source_file = glfw_dep.path("glfw/include/GLFW/glfw3.h"),
        .target = options.target,
        .optimize = options.optimize,
    });
    if (platform == .linux) {
        translate.defineCMacro("GLFW_INCLUDE_VULKAN", null);
    }
    return translate.createModule();
}

fn linkVulkanExample(exe: *std.Build.Step.Compile) void {
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
