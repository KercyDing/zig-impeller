const std = @import("std");

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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
    };

    const sdk = resolveImpellerSdk(b, target.result);
    const mod = addModule(b, options, sdk);

    addLibraryArtifact(b, mod);
    addTests(b, options, sdk, mod);
}

fn addLibraryArtifact(b: *std.Build, mod: *std.Build.Module) void {
    const lib = b.addLibrary(.{
        .name = "impeller",
        .root_module = mod,
    });
    b.installArtifact(lib);
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

fn addImpellerBindings(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk) *std.Build.Module {
    const translate = b.addTranslateC(.{
        .root_source_file = sdk.header,
        .target = options.target,
        .optimize = options.optimize,
    });
    translate.addIncludePath(sdk.include_path);
    return translate.createModule();
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
    run.addPathDir(sdk.lib_path_string);
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
