const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opus_dep = b.dependency("opus", .{ .target = target, .optimize = optimize });

    const lib = b.addLibrary(.{
        .name = "opusenc",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib.root_module.linkLibrary(opus_dep.artifact("opus"));
    lib.root_module.addIncludePath(b.path("include"));
    lib.root_module.addIncludePath(b.path("src"));
    lib.root_module.addCSourceFiles(.{ .files = &sources, .flags = &.{
        "-DHAVE_CONFIG_H",
        "-DOUTSIDE_SPEEX",
        "-DRANDOM_PREFIX=MACH",
    } });
    lib.installHeadersDirectory(b.path("include"), "", .{});
    const config_header = b.addConfigHeader(.{ .style = .blank }, .{
        .PACKAGE_NAME = "opusenc",
        .PACKAGE_VERSION = "0.1",
    });
    lib.root_module.addConfigHeader(config_header);

    // iOS targets require the iOS SDK sysroot (libc headers are not bundled
    // with Zig). Pull the headers, frameworks, and stub libs from the bundled
    // `xcode_frameworks` package so the C sources can find <string.h> etc.
    if (target.result.os.tag == .ios) {
        if (b.lazyDependency("xcode_frameworks", .{
            .target = target,
            .optimize = optimize,
        })) |dep| {
            const subdir = if (target.result.abi == .simulator) "iphonesimulator" else "iphoneos";
            lib.root_module.addSystemFrameworkPath(dep.path(b.fmt("{s}/Frameworks", .{subdir})));
            lib.root_module.addSystemIncludePath(dep.path(b.fmt("{s}/include", .{subdir})));
            lib.root_module.addLibraryPath(dep.path(b.fmt("{s}/lib", .{subdir})));
        }
    }

    b.installArtifact(lib);
}

const sources = [_][]const u8{
    "src/unicode_support.c",
    "src/opus_header.c",
    "src/opusenc.c",
    "src/resample.c",
    "src/ogg_packer.c",
    "src/picture.c",
};
