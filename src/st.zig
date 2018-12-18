const std = @import("std");

const c = std.c;
const debug = std.debug;
const heap = std.heap;
const mem = std.mem;
const os = std.os;
const unicode = std.unicode;

const allocator = heap.c_allocator;

// This was a typedef of uint_least32_t. Is there anywhere where
// uint_least32_t != uint32_t in practice?
const Rune = u32;
const UTF_INVALID = 0xFFFD;

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

pub export fn utf8decode(s: [*]const u8, u: *Rune, slen: usize) usize {
    u.* = UTF_INVALID;
    if (slen == 0)
        return slen;

    const len = unicode.utf8ByteSequenceLength(s[0]) catch return 0;
    if (slen < len)
        return 0;

    u.* = unicode.utf8Decode(s[0..len]) catch return 0;
    return len;
}

pub export fn utf8encode(u: Rune, s: [*]u8) usize {
    const len = unicode.utf8CodepointSequenceLength(u) catch return 0;
    return unicode.utf8Encode(u, s[0..len]) catch unreachable;
}
