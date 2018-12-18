const std = @import("std");

const c = std.c;
const debug = std.debug;
const heap = std.heap;
const math = std.math;
const mem = std.mem;
const os = std.os;
const unicode = std.unicode;

const allocator = heap.c_allocator;

const ESC_BUF_SIZ = (128 * @sizeOf(Rune));
const ESC_ARG_SIZ = 16;
const STR_BUF_SIZ = ESC_BUF_SIZ;
const STR_ARG_SIZ = ESC_ARG_SIZ;

const MODE_WRAP = 1 << 0;
const MODE_INSERT = 1 << 1;
const MODE_ALTSCREEN = 1 << 2;
const MODE_CRLF = 1 << 3;
const MODE_ECHO = 1 << 4;
const MODE_PRINT = 1 << 5;
const MODE_UTF8 = 1 << 6;
const MODE_SIXEL = 1 << 7;

const SEL_REGULAR = 1;
const SEL_RECTANGULAR = 2;

const SEL_IDLE = 0;
const SEL_EMPTY = 1;
const SEL_READY = 2;

const ESC_START = 1 << 0;
const ESC_CSI = 1 << 1;

/// OSC, PM, APC
const ESC_STR = 1 << 2;
const ESC_ALTCHARSET = 1 << 3;

/// a final string was encountered
const ESC_STR_END = 1 << 4;

/// Enter in test mode
const ESC_TEST = 1 << 5;
const ESC_UTF8 = 1 << 6;
const ESC_DCS = 1 << 7;

const ATTR_NULL = 0;
const ATTR_BOLD = 1 << 0;
const ATTR_FAINT = 1 << 1;
const ATTR_ITALIC = 1 << 2;
const ATTR_UNDERLINE = 1 << 3;
const ATTR_BLINK = 1 << 4;
const ATTR_REVERSE = 1 << 5;
const ATTR_INVISIBLE = 1 << 6;
const ATTR_STRUCK = 1 << 7;
const ATTR_WRAP = 1 << 8;
const ATTR_WIDE = 1 << 9;
const ATTR_WDUMMY = 1 << 10;
const ATTR_BOLD_FAINT = ATTR_BOLD | ATTR_FAINT;

const Glyph = extern struct {
    u: Rune,
    mode: c_ushort,
    fg: u32,
    bg: u32,
};

const TCursor = extern struct {
    attr: Glyph,
    x: c_int,
    y: c_int,
    state: u8,
};

/// STR Escape sequence structs
/// ESC type [[ [<priv>] <arg> [;]] <mode>] ESC '\'
const STREscape = extern struct {
    @"type": u8,
    buf: [STR_BUF_SIZ]u8,
    len: c_int,
    args: [STR_ARG_SIZ]?[*]u8,
    narg: c_int,

    const zero = STREscape{
        .@"type" = 0,
        .buf = []u8{0} ** STR_BUF_SIZ,
        .len = 0,
        .args = []?[*]u8{null} ** STR_ARG_SIZ,
        .narg = 0,
    };
};

const Line = [*]Glyph;

/// Internal representation of the screen
const Term = extern struct {
    row: c_int,
    col: c_int,
    line: [*]Line,
    alt: *Line,
    dirty: [*]c_int,
    c: TCursor,
    ocx: c_int,
    ocy: c_int,
    top: c_int,
    bot: c_int,
    mode: c_int,
    esc: c_int,
    trantbl: [4]u8,
    charset: c_int,
    icharset: c_int,
    tabs: *c_int,
};

const Point = extern struct {
    x: c_int,
    y: c_int,
};

const Selection = extern struct {
    mode: c_int,
    @"type": c_int,
    snap: c_int,

    /// Selection variables:
    /// nb – normalized coordinates of the beginning of the selection
    /// ne – normalized coordinates of the end of the selection
    /// ob – original coordinates of the beginning of the selection
    /// oe – original coordinates of the end of the selection
    nb: Point,
    ne: Point,
    ob: Point,
    oe: Point,
    alt: c_int,
};

// This was a typedef of uint_least32_t. Is there anywhere where
// uint_least32_t != uint32_t in practice?
const Rune = u32;
const UTF_INVALID = 0xFFFD;

extern var sel: Selection;
extern var iofd: c_int;
extern var term: Term;
extern var strescseq: STREscape;

extern fn xdrawline(Line, c_int, c_int, c_int) void;
extern fn xstartdraw() c_int;
extern fn xfinishdraw() void;
extern fn xdrawcursor(c_int, c_int, Glyph, c_int, c_int, Glyph) void;
extern fn xsettitle(?[*]const u8) void;

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

pub export fn utf8strchr(s: [*]const u8, u: Rune) ?[*]const u8 {
    const len = mem.len(u8, s);
    const slice = s[0..len];
    var i: usize = 0;
    while (i < len) {
        const plen = unicode.utf8ByteSequenceLength(slice[i]) catch break;
        if (len < i + plen)
            break;

        const p = unicode.utf8Decode(slice[i..][0..plen]) catch break;
        i += len;

        if (p == u)
            return slice[i..].ptr;
    }
    var iter = unicode.Utf8Iterator{
        .bytes = s[0..len],
        .i = 0,
    };

    return null;
}

pub export fn drawregion(x1: c_int, y1: c_int, x2: c_int, y2: c_int) void {
    var y: c_int = y1;
    while (y < y2) : (y += 1) {
        const uy = @intCast(usize, y);
        if (term.dirty[uy] == 0)
            continue;

        term.dirty[uy] = 0;
        xdrawline(term.line[uy], x1, y, x2);
    }
}

pub export fn tsetdirt(top: c_int, bot: c_int) void {
    const ltop = limit(top, 0, term.row - 1);
    const lbot = limit(bot, 0, term.row - 1);
    mem.set(c_int, term.dirty[@intCast(usize, ltop)..@intCast(usize, lbot)], 1);
}

pub export fn tfulldirt() void {
    tsetdirt(0, term.row - 1);
}

pub export fn draw() void {
    var cx = term.c.x;
    if (xstartdraw() == 0)
        return;

    term.ocx = limit(term.ocx, 0, term.col - 1);
    term.ocy = limit(term.ocy, 0, term.row - 1);
    if (term.line[@intCast(usize, term.ocy)][@intCast(usize, term.ocx)].mode & ATTR_WDUMMY != 0)
        term.ocx -= 1;
    if (term.line[@intCast(usize, term.c.y)][@intCast(usize, cx)].mode & ATTR_WDUMMY != 0)
        cx -= 1;

    drawregion(0, 0, term.col, term.row);
    xdrawcursor(
        cx,
        term.c.y,
        term.line[@intCast(usize, term.c.y)][@intCast(usize, cx)],
        term.ocx,
        term.ocy,
        term.line[@intCast(usize, term.ocy)][@intCast(usize, term.ocx)],
    );
    term.ocx = cx;
    term.ocy = term.c.y;
    xfinishdraw();
}

pub fn limit(x: var, a: @typeOf(x), b: @typeOf(x)) @typeOf(x) {
    var res = math.max(x, a);
    return math.min(res, b);
}

pub export fn resettitle() void {
    xsettitle(null);
}

pub export fn redraw() void {
    tfulldirt();
    draw();
}

pub export fn tstrsequence(char: u8) void {
    strescseq = STREscape.zero;
    switch (char) {
        // DCS -- Device Control String
        0x90 => {
            strescseq.@"type" = 'P';
            term.esc |= ESC_DCS;
        },
        // APC -- Application Program Command
        0x9f => strescseq.@"type" = '_',
        // PM -- Privacy Message
        0x9e => strescseq.@"type" = '^',
        // OSC -- Operating System Command
        0x9d => strescseq.@"type" = ']',
        else => strescseq.@"type" = char,
    }
    term.esc |= ESC_STR;
}

pub export fn selected(x: c_int, y: c_int) c_int {
    if (sel.mode == SEL_EMPTY or sel.ob.x == -1 or (sel.alt != 0) != (term.mode & MODE_ALTSCREEN != 0))
        return 0;

    if (sel.@"type" == SEL_RECTANGULAR)
        return @boolToInt(between(y, sel.nb.y, sel.ne.y) and
            between(x, sel.nb.x, sel.ne.x));

    return @boolToInt(between(y, sel.nb.y, sel.ne.y) and
        (y != sel.nb.y or x >= sel.nb.x) and
        (y != sel.ne.y or x <= sel.ne.x));
}

fn between(x: var, a: @typeOf(x), b: @typeOf(x)) bool {
    return a <= x and x <= b;
}
