const std = @import("std");

const c = std.c;
const heap = std.heap;
const mem = std.mem;

const allocator = heap.c_allocator;

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
