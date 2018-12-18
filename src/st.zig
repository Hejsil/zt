const std = @import("std");

const c = std.c;
const debug = std.debug;
const heap = std.heap;
const mem = std.mem;
const os = std.os;

const allocator = heap.c_allocator;

extern var iofd: c_int;

pub export fn xmalloc(len: usize) *c_void {
    return c.malloc(len).?;
}

pub export fn xrealloc(p: *c_void, len: usize) *c_void {
    return c.realloc(p, len).?;
}

pub export fn xstrdup(s: [*]u8) [*]u8 {
    const len = mem.len(u8, s);
    const new = allocator.alloc(u8, len + 1) catch unreachable;
    mem.copy(u8, new, s[0 .. len + 1]);

    return new.ptr;
}

pub export fn tprinter(s: [*]const u8, len: usize) void {
    if (iofd != -1) {
        os.posixWrite(@intCast(i32, iofd), s[0..len]) catch {
            debug.warn("Error writing to output file\n");
            os.close(@intCast(i32, iofd));
            iofd = -1;
        };
    }
}
