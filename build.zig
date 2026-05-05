const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const impeller_sdk = resolveImpellerSdk(b, target.result);

    const impeller_mod = b.createModule(.{
        .root_source_file = b.path("src/impeller.zig"),
        .target = target,
        .optimize = optimize,
    });
    configureImpeller(impeller_mod, impeller_sdk);

    if (target.result.os.tag == .macos) {
        const metal_example_mod = b.createModule(.{
            .root_source_file = b.path("examples/macos/metal_window.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "impeller", .module = impeller_mod },
            },
        });
        configureImpeller(metal_example_mod, impeller_sdk);
        metal_example_mod.addCSourceFile(.{
            .file = b.path("examples/macos/metal_window.m"),
            .flags = &.{ "-fobjc-arc", "-Wno-deprecated-declarations", "-Wno-unguarded-availability-new", "-DGL_SILENCE_DEPRECATION" },
            .language = .objective_c,
        });
        metal_example_mod.addSystemIncludePath(.{ .cwd_relative = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include" });
        metal_example_mod.addFrameworkPath(.{ .cwd_relative = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks" });
        metal_example_mod.linkFramework("AppKit", .{});
        metal_example_mod.linkFramework("Metal", .{});
        metal_example_mod.linkFramework("QuartzCore", .{});

        const metal_example = b.addExecutable(.{
            .name = "metal-window",
            .root_module = metal_example_mod,
        });
        linkImpeller(metal_example_mod, impeller_sdk, target.result);
        b.installArtifact(metal_example);

        const run_metal_example = b.addRunArtifact(metal_example);
        run_metal_example.step.dependOn(b.getInstallStep());
        configureImpellerRuntime(run_metal_example, impeller_sdk);

        const run_metal_step = b.step("run-metal", "Run the macOS Metal window example");
        run_metal_step.dependOn(&run_metal_example.step);
    }
}

const ImpellerSdk = struct {
    include_path: std.Build.LazyPath,
    lib_path: std.Build.LazyPath,
    lib_path_string: []const u8,
    library: std.Build.LazyPath,
    import_library: ?std.Build.LazyPath,
};

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
    run.setEnvironmentVariable("PATH", sdk.lib_path_string);
}

fn resolveImpellerSdk(b: *std.Build, target: std.Target) ImpellerSdk {
    const sdk_path = impellerSdkPath(target) orelse @panic("unsupported Impeller SDK target");
    const sdk_root = b.fmt("vendor/impeller/{s}", .{sdk_path});
    const lib_path = b.fmt("{s}/lib", .{sdk_root});
    return .{
        .include_path = b.path(b.fmt("{s}/include", .{sdk_root})),
        .lib_path = b.path(lib_path),
        .lib_path_string = b.pathFromRoot(lib_path),
        .library = b.path(b.fmt("{s}/{s}", .{ lib_path, impellerLibraryName(target) })),
        .import_library = if (target.os.tag == .windows)
            b.path(b.fmt("{s}/impeller.dll.lib", .{lib_path}))
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

fn impellerSdkPath(target: std.Target) ?[]const u8 {
    return switch (target.os.tag) {
        .macos => switch (target.cpu.arch) {
            .aarch64 => "darwin/arm64",
            .x86_64 => "darwin/x64",
            else => null,
        },
        .linux => switch (target.cpu.arch) {
            .aarch64 => "linux/arm64",
            .x86_64 => "linux/x64",
            else => null,
        },
        .windows => switch (target.cpu.arch) {
            .aarch64 => "windows/arm64",
            .x86_64 => "windows/x64",
            else => null,
        },
        else => null,
    };
}
