# zig-impeller

Zig bindings for Impeller's standalone `impeller.h` API.

<p align="left">
  <img src="https://github.com/user-attachments/assets/938615ee-55aa-4a76-a106-c778151ede53" width="400">
</p>

> Examples [here](https://github.com/KercyDing/zig-impeller-examples).

## Features

- Linux + Vulkan
- macOS + Metal
- Windows + Vulkan
- Zig wrappers for contexts, surfaces, paints, paths, textures, display lists, typography, and basic geometry

## Install

```bash
zig fetch --save git+https://github.com/KercyDing/zig-impeller#main
```

Add the dependency in `build.zig`:

```zig
// ...
const impeller_dep = b.dependency("zig_impeller", .{
    .target = target,
    .optimize = optimize,
});

const exe_mod = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
    .imports = &.{
        .{ .name = "impeller", .module = impeller_dep.module("impeller") },
    },
});
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = exe_mod,
});
// ...
```

Then import it:

```zig
const impeller = @import("impeller");
```

## Minimal drawing

Core drawing code:

```zig
var builder = try impeller.DisplayListBuilder.init(null);
defer builder.deinit();

var paint = try impeller.Paint.init();
defer paint.deinit();

paint.setColor(impeller.srgb(1.0, 1.0, 1.0, 1.0));
builder.drawPaint(paint);

paint.setColor(impeller.srgb(0.2, 0.4, 1.0, 1.0));
builder.drawRect(impeller.rect(120.0, 100.0, 240.0, 160.0), paint);

var list = try builder.build();
defer list.deinit();

try surface.draw(list);
try surface.present();
```

## Examples

Runnable GLFW examples now live in the separate `zig-impeller-examples` repository so this package stays a pure library dependency with no GLFW requirement.

## Status

- All of `impeller.h` is wrapped
- `zig build test` runs unit tests
- `FragmentProgram` is wrapped, but shader packaging is not documented here yet

## LICENSE

[MIT](LICENSE)
