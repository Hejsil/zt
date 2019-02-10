const std = @import("std");

const debug = std.debug;
const mem = std.mem;

const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) !void {
    const fontconfig_cflags = try b.exec([][]const u8{ "pkg-config", "--cflags", "fontconfig" });
    const freetype2_cflags = try b.exec([][]const u8{ "pkg-config", "--cflags", "freetype2" });
    const cflags = try concat(b.allocator, []const u8, [][]const []const u8{
        [][]const u8{
            "-std=gnu99",
            "-DVERSION=\"0.8.1\"",
            "-D_XOPEN_SOURCE=600",
        },
        try split(b.allocator, fontconfig_cflags, " \t\r\n"),
        try split(b.allocator, freetype2_cflags, " \t\r\n"),
    });

    const exe = b.addCExecutable("zt");
    exe.addCompileFlags(cflags);

    linkLibs(exe, [][]const u8{
        "m",
        "rt",
        "X11",
        "util",
        "Xft",
    });
    try linkPackageConfigLibs(b, exe, "fontconfig");
    try linkPackageConfigLibs(b, exe, "freetype2");

    inline for ([][]const u8{
        "st",
        "x",
    }) |obj_name| {
        const obj = b.addCObject(obj_name, obj_name ++ ".c");
        obj.addCompileFlags(cflags);
        exe.addObject(obj);
    }

    inline for ([][]const u8{"st"}) |obj_name| {
        const obj = b.addObject(obj_name ++ "-zig", "src/" ++ obj_name ++ ".zig");
        exe.addObject(obj);
    }

    const run_step = b.step("run", "Run the zt");
    const run_cmd = b.addCommand(".", b.env_map, [][]const u8{exe.getOutputPath()});
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(&exe.step);

    b.default_step.dependOn(&exe.step);
}

fn linkLibs(exe: *LibExeObjStep, libs: []const []const u8) void {
    for (libs) |lib|
        exe.linkSystemLibrary(lib);
}

fn linkPackageConfigLibs(b: *Builder, exe: *LibExeObjStep, package: []const u8) !void {
    const libs = try b.exec([][]const u8{ "pkg-config", "--libs", package });
    var lib_iter = mem.tokenize(libs, " \t\r\n");
    while (lib_iter.next()) |lib| {
        if (!mem.startsWith(u8, lib, "-l"))
            return error.Unexpected;

        exe.linkSystemLibrary(lib[2..]);
    }
}

fn concat(allocator: *mem.Allocator, comptime T: type, items: []const []const T) ![]T {
    var res = std.ArrayList(T).init(allocator);
    defer res.deinit();

    for (items) |sub_items| {
        for (sub_items) |item|
            try res.append(item);
    }

    return res.toOwnedSlice();
}

fn split(allocator: *mem.Allocator, buffer: []const u8, split_bytes: []const u8) ![][]const u8 {
    var res = std.ArrayList([]const u8).init(allocator);
    defer res.deinit();

    var iter = mem.tokenize(buffer, split_bytes);
    while (iter.next()) |s|
        try res.append(s);

    return res.toOwnedSlice();
}
