#!/usr/bin/env python3
# -----------------------------------------------------------------------------
#  gen_vdpview.py -- page generator for VDPVIEW.COM (visual VDP check)
#
#  Every page is described here: register settings, palette, VRAM image and
#  the way it is shown (static, line interrupt driven, HR/VR polling).
#  Output:
#     VDPVIEW.INC  page table + byte code interpreted by VDPVIEW.ASM
#     VDPVIEW.md   check list (Japanese) with reference screenshots
# -----------------------------------------------------------------------------
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# --- byte code ---------------------------------------------------------------
OP_END = 0x00
OP_REG = 0x01      # r, v
OP_P4 = 0x02       # v
OP_PAL = 0x03      # count16, bytes (R#16 = 0 is set before)
OP_VRAM = 0x04     # a24, RLE stream (never crosses a 16 KB boundary)
OP_SHOW = 0x05     # static, wait key
OP_LINE = 0x06     # r0, start_r19, entries ...
OP_POLL = 0x07     # vr_rise, vr_fall, n, entries ...
OP_CMD = 0x08      # 15 bytes for R#32-R#46, wait CE

# --- 5x7 font ----------------------------------------------------------------
FONT = {
    ' ': (0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00),
    'A': (0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11),
    'B': (0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E),
    'C': (0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E),
    'D': (0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C),
    'E': (0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F),
    'F': (0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10),
    'G': (0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F),
    'H': (0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11),
    'I': (0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E),
    'J': (0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C),
    'K': (0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11),
    'L': (0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F),
    'M': (0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11),
    'N': (0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11),
    'O': (0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E),
    'P': (0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10),
    'Q': (0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D),
    'R': (0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11),
    'S': (0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E),
    'T': (0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04),
    'U': (0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E),
    'V': (0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04),
    'W': (0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A),
    'X': (0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11),
    'Y': (0x11, 0x11, 0x11, 0x0A, 0x04, 0x04, 0x04),
    'Z': (0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F),
    '0': (0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E),
    '1': (0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E),
    '2': (0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F),
    '3': (0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E),
    '4': (0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02),
    '5': (0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E),
    '6': (0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E),
    '7': (0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08),
    '8': (0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E),
    '9': (0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C),
    '-': (0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00),
    '+': (0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00),
    '=': (0x00, 0x00, 0x1F, 0x00, 0x1F, 0x00, 0x00),
    ':': (0x00, 0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0x00),
    '.': (0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C),
    ',': (0x00, 0x00, 0x00, 0x00, 0x0C, 0x04, 0x08),
    '/': (0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x00),
    '(': (0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02),
    ')': (0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08),
    '#': (0x0A, 0x0A, 0x1F, 0x0A, 0x1F, 0x0A, 0x0A),
    '<': (0x02, 0x04, 0x08, 0x10, 0x08, 0x04, 0x02),
    '>': (0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08),
    '*': (0x00, 0x04, 0x15, 0x0E, 0x15, 0x04, 0x00),
}

# --- palettes ----------------------------------------------------------------
MSX2_PALETTE = [
    (0, 0, 0), (0, 0, 0), (1, 6, 1), (3, 7, 3), (1, 1, 7), (2, 3, 7), (5, 1, 1), (2, 6, 7),
    (7, 1, 1), (7, 3, 3), (6, 6, 1), (6, 6, 4), (1, 4, 1), (6, 2, 5), (5, 5, 5), (7, 7, 7),
]

RED = 8
WHITE = 15
BLUE = 4
BLACK = 1


def pal_bytes(pal):
    out = []
    for r, g, b in pal:
        out += [(r << 4) | b, g]
    return out


# GRB332 byte of the fixed sprite colours in SCREEN 8 (V9958 compatible)
SC8_SPRITE_COLOR = [0x00, 0x01, 0x0C, 0x0D, 0x60, 0x61, 0x6C, 0x6D,
                    0x9D, 0x03, 0x1C, 0x1F, 0xE0, 0xE3, 0xFC, 0xFF]
SC8_RED = 0x1C
SC8_WHITE = 0xFF


# --- VRAM model --------------------------------------------------------------
class Screen:
    """Background image in VRAM. mode: G2 G4 G5 G6 G7 (CPU logical addresses)."""

    def __init__(self, mode, lines=212):
        self.mode = mode
        self.vram = bytearray(0x20000)
        self.lines = lines
        self.width = 512 if mode in ('G5', 'G6') else 256
        self.g2 = None
        if mode == 'G2':
            self.g2 = [[BLACK] * 256 for _ in range(192)]

    # x is in dots of the mode (0..511 for G5/G6)
    def pset(self, x, y, c):
        if x < 0 or y < 0 or x >= self.width or y >= 256:
            return
        m = self.mode
        v = self.vram
        if m == 'G2':
            if y < 192:
                self.g2[y][x] = c
        elif m == 'G4':
            a = y * 128 + (x >> 1)
            if x & 1:
                v[a] = (v[a] & 0xF0) | (c & 15)
            else:
                v[a] = (v[a] & 0x0F) | ((c & 15) << 4)
        elif m == 'G5':
            a = y * 128 + (x >> 2)
            sh = (3 - (x & 3)) * 2
            v[a] = (v[a] & ~(3 << sh) & 0xFF) | ((c & 3) << sh)
        elif m == 'G6':
            a = y * 256 + (x >> 1)
            if x & 1:
                v[a] = (v[a] & 0xF0) | (c & 15)
            else:
                v[a] = (v[a] & 0x0F) | ((c & 15) << 4)
        elif m == 'G7':
            v[y * 256 + x] = c & 0xFF

    # x, y in 256 dot units, sets both half dots in 512 dot modes
    def dot(self, x, y, c):
        if self.width == 512:
            self.pset(x * 2, y, c)
            self.pset(x * 2 + 1, y, c)
        else:
            self.pset(x, y, c)

    def box(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.dot(xx, yy, c)

    def hbox(self, x, y, w, h, c):
        """box in dots of the mode."""
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.pset(xx, yy, c)

    def text(self, x, y, s, c, scale=1):
        for ch in s:
            g = FONT[ch.upper()]
            for r in range(7):
                for b in range(5):
                    if g[r] & (0x10 >> b):
                        for sy in range(scale):
                            for sx in range(scale):
                                self.dot(x + b * scale + sx, y + r * scale + sy, c)
            x += 6 * scale

    def finish(self):
        """Create G2 tables from the pixel image (one colour pair per 8x1)."""
        if self.mode != 'G2':
            return
        v = self.vram
        for blk in range(3):
            for i in range(256):
                v[0x1800 + blk * 256 + i] = i
        for y in range(192):
            for cx in range(32):
                row = self.g2[y][cx * 8:cx * 8 + 8]
                cols = sorted(set(row) - {BLACK})
                if len(cols) > 1:
                    raise ValueError('G2 colour clash at %d,%d: %s' % (cx * 8, y, cols))
                fg = cols[0] if cols else WHITE
                pat = 0
                for b in range(8):
                    if row[b] != BLACK:
                        pat |= 0x80 >> b
                a = (y >> 6) * 2048 + cx * 8 + ((y >> 3) & 7) * 256 + (y & 7)
                v[a] = pat
                v[0x2000 + a] = (fg << 4) | BLACK


# --- RLE ---------------------------------------------------------------------
def rle(data):
    out = []
    lit = []

    def flush():
        while lit:
            n = min(len(lit), 127)
            out.append(n)
            out.extend(lit[:n])
            del lit[:n]

    i = 0
    n = len(data)
    while i < n:
        j = i
        while j < n and data[j] == data[i]:
            j += 1
        run = j - i
        if run >= 3:
            flush()
            while run >= 3:
                if run > 129:
                    m = min(run, 0xFFFF)
                    out += [0xFF, m & 0xFF, m >> 8, data[i]]
                else:
                    m = run
                    out += [m + 0x7D, data[i]]
                run -= m
            lit.extend([data[i]] * run)
        else:
            lit.extend(data[i:j])
        i = j
    flush()
    out.append(0)
    return out


def vram_ops(vram, ref=None):
    """Emit VRAM ops for the spans that differ from ref (VRAM is cleared before)."""
    if ref is None:
        ref = bytes(len(vram))
    out = []
    for base in range(0, 0x20000, 0x4000):
        chunk = vram[base:base + 0x4000]
        rchunk = ref[base:base + 0x4000]
        i = 0
        while i < 0x4000:
            if chunk[i] == rchunk[i]:
                i += 1
                continue
            s = i
            e = i
            zeros = 0
            while e < 0x4000 and zeros < 32:
                if chunk[e] == rchunk[e]:
                    zeros += 1
                else:
                    zeros = 0
                e += 1
            e -= zeros
            a = base + s
            out += [OP_VRAM, a & 0xFF, (a >> 8) & 0xFF, a >> 16]
            out += rle(chunk[s:e])
            i = e
    return out


# --- page --------------------------------------------------------------------
PAGES = []

MODE_REGS = {
    # SCREEN 2, sprite mode 1: name 1800h, colour 2000h, pattern 0000h
    'G2': [(0, 0x02), (2, 0x06), (3, 0xFF), (4, 0x03), (10, 0x00),
           (5, 0x36), (11, 0x00), (6, 0x07)],
    # SCREEN 5/6: sprite colour 7400h, attribute 7600h, pattern 7800h
    'G4': [(0, 0x06), (2, 0x1F), (5, 0xEF), (11, 0x00), (6, 0x0F)],
    'G5': [(0, 0x08), (2, 0x1F), (5, 0xEF), (11, 0x00), (6, 0x0F)],
    # SCREEN 7/8: sprite pattern F000h, colour F800h, attribute FA00h
    'G6': [(0, 0x0A), (2, 0x1F), (5, 0xF7), (11, 0x01), (6, 0x1E)],
    'G7': [(0, 0x0E), (2, 0x1F), (5, 0xF7), (11, 0x01), (6, 0x1E)],
}

SPR_TABLES = {
    'G2': dict(attr=0x1B00, color=None, pat=0x3800),
    'G4': dict(attr=0x7600, color=0x7400, pat=0x7800),
    'G5': dict(attr=0x7600, color=0x7400, pat=0x7800),
    'G6': dict(attr=0xFA00, color=0xF800, pat=0xF000),
    'G7': dict(attr=0xFA00, color=0xF800, pat=0xF000),
}


class Page:
    def __init__(self, title, mode, lines=212, v9968=False):
        self.title = title
        self.mode = mode
        self.lines = lines
        self.v9968 = v9968
        self.scr = Screen(mode, lines)
        self.regs = list(MODE_REGS[mode])
        self.r1 = 0x40
        self.r8 = 0x08
        self.r9 = 0x80 if lines == 212 else 0x00
        self.r7 = BLUE
        self.r20 = None
        self.extra_regs = []
        self.palette = pal_bytes(MSX2_PALETTE)
        self.show = [OP_SHOW]
        self.doc = ''
        self.check = []
        self.base = None
        self.base_image = None
        self.fills = []
        self.fill_ref = None

    def fill(self, x, y, w, h, c):
        """Box (256 dot units) drawn by HMMV before the VRAM data."""
        m = self.mode
        assert m != 'G2' and self.base is None
        k = 2 if m in ('G5', 'G6') else 1
        if m in ('G4', 'G5'):
            assert x % 2 == 0 and w % 2 == 0
        if self.fill_ref is None:
            self.fill_ref = Screen(m, self.lines)
        self.fill_ref.box(x, y, w, h, c)
        self.scr.box(x, y, w, h, c)
        byte = {'G4': (c & 15) * 0x11, 'G6': (c & 15) * 0x11,
                'G5': (c & 3) * 0x55, 'G7': c & 0xFF}[m]
        dx, nx = x * k, w * k
        self.fills.append([0, 0, 0, 0, dx & 0xFF, dx >> 8, y & 0xFF, y >> 8,
                           nx & 0xFF, nx >> 8, h & 0xFF, h >> 8, byte, 0, 0xC0])

    def set_base(self, rows):
        """The current image repeats every `rows` lines (G4, 256 lines).
        Only the first rows are written; HMMM copies the rest. Later drawing
        is written as the difference to that image."""
        seed = bytearray(0x20000)
        seed[:rows * 128] = self.scr.vram[:rows * 128]
        img = bytearray(0x20000)
        for y in range(256):
            img[y * 128:y * 128 + 128] = self.scr.vram[(y % rows) * 128:(y % rows) * 128 + 128]
        cmds = []
        n = rows
        while n < 256:
            m = min(n, 256 - n)
            cmds.append([0, 0, 0, 0, 0, 0, n & 0xFF, n >> 8,
                         0, 1, m & 0xFF, m >> 8, 0, 0, 0xD0])
            n += m
        self.base = (seed, cmds)
        self.base_image = img

    def code(self):
        out = []
        for r, v in self.regs:
            out += [OP_REG, r, v]
        out += [OP_REG, 8, self.r8, OP_REG, 9, self.r9, OP_REG, 7, self.r7]
        if self.r20 is not None:
            out += [OP_P4, 0x00, OP_REG, 20, self.r20, OP_P4, 0x80]
        for r, v in self.extra_regs:
            out += [OP_REG, r, v]
        n = len(self.palette)
        out += [OP_PAL, n & 0xFF, n >> 8] + self.palette
        self.scr.finish()
        if self.base is not None:
            seed, cmds = self.base
            out += vram_ops(seed)
            for c in cmds:
                out += [OP_CMD] + c
            out += vram_ops(self.scr.vram, self.base_image)
        elif self.fills:
            for c in self.fills:
                out += [OP_CMD] + c
            out += vram_ops(self.scr.vram, self.fill_ref.vram)
        else:
            out += vram_ops(self.scr.vram)
        out += [OP_REG, 1, self.r1]
        out += self.show
        return out


def page(*a, **k):
    p = Page(*a, **k)
    PAGES.append(p)
    return p

# --- sprites (mode 1 / mode 2) ------------------------------------------------
def make_pattern(size):
    rows = []
    for r in range(size):
        bits = 0
        for c in range(size):
            on = True
            if c - r > size * 5 // 8:
                on = False
            if size == 16 and r in (6, 7) and c in (4, 5):
                on = False
            if size == 8 and r == 3 and c == 2:
                on = False
            if r == size - 1 and c >= size - size // 4:
                on = False
            if on:
                bits |= 1 << (size - 1 - c)
        rows.append(bits)
    return rows


class Sprite:
    def __init__(self, x, y, color=WHITE, ec_rows=(), cc_rows=(), pattern=None):
        self.x = x
        self.y = y
        self.color = color          # int or list per row
        self.ec_rows = set(ec_rows)
        self.cc_rows = set(cc_rows)
        self.pattern = pattern      # index into the pattern list


class SpriteSet:
    def __init__(self, page, smode, size, mag):
        self.page = page
        self.smode = smode
        self.size = size
        self.mag = mag
        self.patterns = [make_pattern(size)]
        self.sprites = []
        page.r1 = (page.r1 & ~0x03) | (0x02 if size == 16 else 0) | (1 if mag == 2 else 0)

    def add(self, *a, **k):
        s = Sprite(*a, **k)
        if s.pattern is None:
            s.pattern = 0
        self.sprites.append(s)
        return s

    def row_color(self, s, row):
        c = s.color[row] if isinstance(s.color, (list, tuple)) else s.color
        return c

    def row_ec(self, s, row):
        return s.x < 0 or row in s.ec_rows

    def attr_x(self, s):
        return s.x + 32 if s.x < 0 else s.x

    def attr_y(self, s):
        y = (s.y - 1) & 0xFF
        term = 208 if self.smode == 1 else 216
        assert y != term, 'sprite Y hits the terminator'
        return y

    def write(self):
        t = SPR_TABLES[self.page.mode]
        v = self.page.scr.vram
        step = 32 if self.size == 16 else 8
        for i, p in enumerate(self.patterns):
            a = t['pat'] + i * step
            for r in range(self.size):
                if self.size == 16:
                    v[a + r] = p[r] >> 8
                    v[a + 16 + r] = p[r] & 0xFF
                else:
                    v[a + r] = p[r]
        pn = 4 if self.size == 16 else 1
        for i, s in enumerate(self.sprites):
            a = t['attr'] + i * 4
            v[a] = self.attr_y(s)
            v[a + 1] = self.attr_x(s)
            v[a + 2] = s.pattern * pn
            if self.smode == 1:
                v[a + 3] = (self.row_color(s, 0) & 15) | (0x80 if s.x < 0 else 0)
            else:
                for r in range(16):
                    c = self.row_color(s, min(r, self.size - 1)) & 15
                    if self.row_ec(s, r):
                        c |= 0x80
                    if r in s.cc_rows:
                        c |= 0x40
                    v[t['color'] + i * 16 + r] = c
        a = t['attr'] + len(self.sprites) * 4
        v[a] = 208 if self.smode == 1 else 216

    def render(self):
        """Expected sprite image: dict (x, y) -> colour code (x in 256 dots)."""
        out = {}
        limit = 4 if self.smode == 1 else 8
        sh = self.size * self.mag
        for line in range(self.page.lines):
            n = 0
            line_px = {}
            has_normal = False
            for s in self.sprites:
                off = (line - self.attr_y(s) - 1) & 0xFF
                if off >= sh:
                    continue
                n += 1
                if n > limit:
                    break
                row = off // self.mag
                cc = self.smode == 2 and row in s.cc_rows
                if cc and not has_normal:
                    continue
                if not cc:
                    has_normal = True
                c = self.row_color(s, row)
                x0 = self.attr_x(s) - (32 if self.row_ec(s, row) else 0)
                bits = self.patterns[s.pattern][row]
                for col in range(self.size):
                    if not bits & (1 << (self.size - 1 - col)):
                        continue
                    for k in range(self.mag):
                        x = x0 + col * self.mag + k
                        if x < 0 or x > 255:
                            continue
                        if cc:
                            line_px[x] = line_px.get(x, 0) | c
                        elif x not in line_px:
                            line_px[x] = c
            for x, c in line_px.items():
                out[(x, line)] = c
        return out


def red_of(mode):
    return {'G2': RED, 'G4': RED, 'G6': RED, 'G5': 2, 'G7': SC8_RED}[mode]


def edge_page(title, mode, smode, size, mag, lines):
    p = page(title, mode, lines)
    p.r7 = 0
    if mode == 'G5':
        p.palette = pal_bytes([(0, 0, 0), (1, 1, 7), (7, 1, 1), (7, 7, 7)] + MSX2_PALETTE[4:])
    ss = SpriteSet(p, smode, size, mag)
    sw = sh = size * mag
    h = lines
    # top
    ss.add(-sw // 2, -sh // 2)
    ss.add(64, 1 - sh)
    ss.add(112, -sh // 2)
    ss.add(256 - sw // 2, -sh // 2)
    # left / centre / right
    ys = [50, 50 + sh + 8, 50 + 2 * (sh + 8)]
    for i, y in enumerate(ys):
        ss.add([-1, -sw // 2, 1 - sw][i], y)
        ss.add([255, 256 - sw // 2, 257 - sw][i], y)
        if i == 1:
            if smode == 2:
                ss.add(140, y, ec_rows=range(size // 4, size // 2))
            else:
                ss.add(124, y)
    # bottom
    ss.add(-sw // 2, h - sh // 2)
    ss.add(64, h - 1)
    ss.add(112, h - sh // 2)
    ss.add(256 - sw // 2, h - sh // 2)
    ss.write()
    red = red_of(mode)
    for (x, y) in ss.render():
        p.scr.dot(x, y, red)
    tc = 3 if mode == 'G5' else (0xFC if mode == 'G7' else 11)
    p.scr.text(40, 22, title, tc)
    p.scr.text(40, 32, 'NO RED = OK', tc)
    return p, ss

# --- show helpers --------------------------------------------------------------
def pairs(regs):
    out = []
    for r, v in regs:
        out += [v & 0xFF, 0x80 | r]
    return [len(out)] + out


def line_show(p, entries, r23=0):
    """entries: [(line, [(reg, val), ...]), ...] in display order.
    The last entry must restore the state at the top of the frame."""
    r0 = dict(p.regs)[0] | 0x10
    r19 = []
    cur23 = r23
    for line, regs in entries:
        r19.append((line + cur23) & 0xFF)
        for r, v in regs:
            if r == 23:
                cur23 = v
    assert cur23 == r23, 'last entry has to restore R#23'
    out = [OP_LINE, r0, r19[0]]
    for i, (line, regs) in enumerate(entries):
        last = i == len(entries) - 1
        out += pairs(regs) + [r19[0] if last else r19[i + 1], 1 if last else 0]
    p.show = out
    p.lint = entries


def poll_show(p, vr_rise, vr_fall, entries):
    out = [OP_POLL] + pairs(vr_rise) + pairs(vr_fall) + [len(entries)]
    for hr, regs in entries:
        out += [hr] + pairs(regs)
    p.show = out


def copy_render(scr, img, dx, dy, ymin=0, ymax=255, conv=lambda c: c):
    for (x, y), c in img.items():
        if ymin <= y <= ymax:
            scr.dot(x + dx, y + dy, conv(c))


SOLID16 = [0xFFFF] * 16


# --- pages: sprite edges -------------------------------------------------------
def build_edge_pages():
    p, _ = edge_page('SC2 SPRITE M1 8X8', 'G2', 1, 8, 1, 192)
    p.doc = 'SCREEN 2 / スプライトモード1 / 8x8 等倍'
    p, _ = edge_page('SC2 SPRITE M1 16X16 X2', 'G2', 1, 16, 2, 192)
    p.doc = 'SCREEN 2 / スプライトモード1 / 16x16 拡大'
    p, _ = edge_page('SC5 SPRITE M2 16X16', 'G4', 2, 16, 1, 212)
    p.doc = 'SCREEN 5 / スプライトモード2 / 16x16 等倍 / 212ライン'
    p, _ = edge_page('SC6 SPRITE M2 16X16 X2', 'G5', 2, 16, 2, 212)
    p.doc = 'SCREEN 6 / スプライトモード2 / 16x16 拡大 / 212ライン'
    p, _ = edge_page('SC7 SPRITE M2 8X8 192L', 'G6', 2, 8, 1, 192)
    p.doc = 'SCREEN 7 / スプライトモード2 / 8x8 等倍 / 192ライン'
    p, _ = edge_page('SC8 SPRITE M2 8X8 X2', 'G7', 2, 8, 2, 212)
    p.doc = 'SCREEN 8 / スプライトモード2 / 8x8 拡大 / 212ライン'


# --- pages: colours --------------------------------------------------------------
def build_color_pages():
    # SCREEN 5: colour codes, TP, CC, priority, 9th sprite
    p = page('SC5 SPRITE COLOR', 'G4')
    p.palette = pal_bytes([(2, 2, 2)] + MSX2_PALETTE[1:])
    ss = SpriteSet(p, 2, 16, 1)
    ss.patterns[0] = SOLID16
    for row_y in (40, 120):
        for i in range(8):
            ss.add(i * 32, row_y, color=[2 * i] * 8 + [2 * i + 1] * 8)
        if row_y == 40:
            ss.add(16, row_y, color=RED)          # 9th sprite: must be hidden
    ss.add(40, 150, color=2)
    ss.add(48, 150, color=4, cc_rows=range(16))
    ss.add(120, 150, color=10)
    ss.add(128, 150, color=13)
    ss.add(200, 192, color=RED, cc_rows=range(16))   # CC without parent: hidden
    ss.write()
    img = ss.render()
    copy_render(p.scr, img, 16, 0, 0, 140)
    copy_render(p.scr, img, 0, 20, 141, 169)
    p.scr.text(8, 4, 'SC5 SPRITE COLOR', 11)
    p.scr.text(8, 14, 'SPRITE = SWATCH, NO RED', 11)
    p.scr.text(8, 28, 'TP=0', 15)
    p.scr.text(8, 108, 'TP=1', 15)
    p.scr.text(160, 150, 'CC / PRIO', 15)
    line_show(p, [(104, [(8, 0x28)]), (214, [(8, 0x08)])])
    p.doc = 'SCREEN 5 のスプライト色（色0〜15、TP=0/1、CC 合成、優先順位、9枚目非表示）'

    # SCREEN 6: border bands + sprite colour pairs
    p = page('SC6 BORDER + SPRITE', 'G5')
    pal4 = [(0, 0, 0), (1, 1, 7), (7, 5, 0), (7, 7, 7)]
    p.palette = pal_bytes(pal4 + MSX2_PALETTE[4:])
    p.r8 = 0x28
    ents = []
    for k in range(16):
        y = 12 + k * 12
        for yy in range(y, y + 12):
            for hx in list(range(0, 16)) + list(range(496, 512)):
                p.scr.pset(hx, yy, (k >> 2) if (hx & 1) == 0 else (k & 3))
        ents.append((y, [(7, k)]))
    ents.append((214, [(7, 0)]))
    line_show(p, ents)
    ss = SpriteSet(p, 2, 16, 1)
    ss.patterns[0] = SOLID16
    for i in range(8):
        ss.add(16 + i * 28, 140, color=i)
        ss.add(16 + i * 28, 176, color=i + 8)
    ss.write()
    for (x, y), c in ss.render().items():
        p.scr.pset(x * 2, y + 18, c >> 2)
        p.scr.pset(x * 2 + 1, y + 18, c & 3)
    p.scr.text(24, 2, 'SC6 BORDER/SPRITE', 3)
    p.scr.text(24, 30, 'NO SEAM AT LEFT/RIGHT', 3)
    p.scr.text(24, 40, 'SPRITE = SWATCH', 3)
    p.doc = 'SCREEN 6 の周辺色（R#7 の値0〜15を12ラインごとに変更）とスプライト色'

    # SCREEN 8: border bands + fixed sprite colours
    p = page('SC8 BORDER + SPRITE', 'G7')
    p.r8 = 0x28
    vals = [0x00, 0x03, 0x1C, 0xE0, 0x1F, 0xE3, 0xFC, 0xFF,
            0x49, 0x92, 0x6D, 0xB6, 0x24, 0x6A, 0xD5, 0x00]
    ents = []
    for k, v in enumerate(vals):
        y = 12 + k * 12
        p.fill(0, y, 8, 12, v)
        p.fill(248, y, 8, 12, v)
        ents.append((y, [(7, v)]))
    ents.append((214, [(7, 0x00)]))
    line_show(p, ents)
    ss = SpriteSet(p, 2, 16, 1)
    ss.patterns[0] = SOLID16
    for i in range(8):
        ss.add(16 + i * 28, 140, color=i)
        ss.add(16 + i * 28, 176, color=i + 8)
    ss.write()
    for s in ss.sprites:
        p.fill(s.x, s.y + 18, 16, 16, SC8_SPRITE_COLOR[s.color])
    p.scr.text(24, 2, 'SC8 BORDER/SPRITE', 0xFC)
    p.scr.text(24, 30, 'NO SEAM AT LEFT/RIGHT', 0xFC)
    p.scr.text(24, 40, 'SPRITE = SWATCH', 0xFC)
    p.doc = 'SCREEN 8 の周辺色（R#7 の GRB332 値）とスプライト固定16色'

    # SCREEN 11 (YJK + YAE): border and sprites use the palette
    p = page('SC11 BORDER + SPRITE', 'G7')
    p.extra_regs = [(25, 0x18)]
    p.r8 = 0x28
    p.palette = pal_bytes([(2, 2, 2)] + MSX2_PALETTE[1:])
    ents = []
    for k in range(16):
        y = 12 + k * 12
        p.fill(0, y, 8, 12, (k << 4) | 0x08)
        p.fill(248, y, 8, 12, (k << 4) | 0x08)
        ents.append((y, [(7, k | ((15 - k) << 4))]))
    ents.append((214, [(7, 0x00)]))
    line_show(p, ents)
    ss = SpriteSet(p, 2, 16, 1)
    ss.patterns[0] = SOLID16
    for i in range(8):
        ss.add(16 + i * 28, 140, color=i)
        ss.add(16 + i * 28, 176, color=i + 8)
    ss.write()
    for s in ss.sprites:
        p.fill(s.x, s.y + 18, 16, 16, (s.color << 4) | 0x08)
    for y in range(64, 72):
        for x in range(16, 240, 4):
            j = ((x - 16) // 4) % 64 - 32
            k = (x - 16) // 14 - 16
            for i in range(4):
                yv = ((x + i - 16) * 31 // 223) & 0x1E
                low = [k & 7, (k >> 3) & 7, j & 7, (j >> 3) & 7][i]
                p.scr.pset(x + i, y, (yv << 3) | low)
    p.scr.text(24, 2, 'SC11 BORDER/SPRITE', (11 << 4) | 0x08)
    p.scr.text(24, 30, 'NO SEAM AT LEFT/RIGHT', (11 << 4) | 0x08)
    p.scr.text(24, 40, 'SPRITE = SWATCH', (11 << 4) | 0x08)
    p.doc = 'SCREEN 11（YJK+YAE）の周辺色（R#7 下位4ビットのパレット）とスプライト色（パレット）、YJK グラデーション'


# --- pages: YJK (added after the V9968 pages to keep the earlier page numbers) ---
def build_yjk_pages():
    # SCREEN 12 (YJK, YAE=0): the border is palette R#7[3:0], never the YJK decode of R#7
    p = page('SC12 BORDER + SPRITE', 'G7')
    p.extra_regs = [(25, 0x08)]
    p.palette = pal_bytes(MSX2_PALETTE)
    ss = SpriteSet(p, 2, 8, 1)
    ss.patterns[0] = [0xFF] * 8
    ents = []
    for k in range(16):
        y = 12 + k * 12
        ents.append((y, [(7, k | ((15 - k) << 4))]))
        if k:
            ss.add(0, y + 2, color=k)
            ss.add(248, y + 2, color=k)
    ents.append((214, [(7, 0x00)]))
    line_show(p, ents)
    ss.write()
    p.scr.text(24, 2, 'SC12 BORDER/SPRITE', 0xF8)
    p.scr.text(24, 30, 'NO SEAM AT LEFT/RIGHT', 0xF8)
    p.doc = 'SCREEN 12（YJK、YAE=0）の周辺色（R#7 下位4ビットのパレット）。画面端のスプライト（パレット色）と比べる'


# --- pages: raster -------------------------------------------------------------
def build_raster_pages():
    # border colour changed by the line interrupt
    p = page('SC5 LINE INT BORDER', 'G4')
    ents = []
    cols = [2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 3]
    for k, c in enumerate(cols):
        y = 16 + k * 16
        ents.append((y, [(7, c)]))
        p.scr.box(0, y, 4, 1, 15)
        p.scr.box(252, y, 4, 1, 15)
        p.scr.text(8, y + 4, 'L%d' % y, 1 if c in (3, 11, 14, 15) else 15)
    ents.append((214, [(7, 1)]))
    ents.append((230, [(7, 4)]))
    line_show(p, ents)
    p.scr.text(48, 4, 'SC5 LINE INT BORDER', 15)
    p.doc = '走査線割込み（16ラインごと、下の周辺部 214/230）で周辺色を変更'

    # scroll changed by the line interrupt
    p = page('SC5 LINE INT SCROLL', 'G4')
    p.extra_regs = [(25, 0x02)]
    for y in range(256):
        band = (y >> 4) & 1
        for x in range(256):
            c = 4 if band else 12
            if x % 32 == 0:
                c = 15
            elif x % 8 == 0:
                c = 14
            p.scr.dot(x, y, c)
    p.set_base(32)
    for y in range(0, 256, 16):
        p.scr.text(12, y + 5, 'Y=%03d' % y, 15)
    ents = [(48, [(23, 64)])]
    for k, (r26, r27) in enumerate([(1, 0), (2, 3), (4, 7)]):
        ents.append((96 + k * 16, [(26, r26), (27, r27)]))
    ents.append((144, [(23, 200), (26, 0), (27, 0)]))
    ents.append((216, [(23, 0)]))
    line_show(p, ents)
    p.doc = '走査線割込みで R#23（ライン48: 64、ライン144: 200）と R#26/R#27（ライン96/112/128 で左へ 8/13/25 ドット）を変更'

    # HR / VR polling
    p = page('SC5 POLLING HR VR', 'G4')
    ents = []
    cols = [2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
    for k, c in enumerate(cols):
        ents.append((16, [(7, c)]))
    poll_show(p, [(7, 13)], [(7, 4)], ents)
    p.scr.text(48, 100, 'SC5 POLLING HR VR', 15)
    p.doc = 'S#2 の VR 立ち上がりで紫、立ち下がりで青、その後 HR を16回数えるごとに周辺色を変更'


# --- output --------------------------------------------------------------------
def write_inc(path):
    lines = ['; generated by gen_vdpview.py -- do not edit', '']
    lines.append('page_count::\n\t\tdb\t\t%d' % len(PAGES))
    lines.append('page_table::')
    for i, p in enumerate(PAGES):
        lines.append('\t\tdb\t\t%d\n\t\tdw\t\tpage_%02d' % (1 if p.v9968 else 0, i))
    total = 0
    for i, p in enumerate(PAGES):
        code = p.code()
        total += len(code)
        p.size = len(code)
        lines.append('page_%02d:\t\t; %s' % (i, p.title))
        for k in range(0, len(code), 16):
            lines.append('\t\tdb\t\t' + ', '.join('0x%02X' % b for b in code[k:k + 16]))
    with open(path, 'w', newline='\r\n') as f:
        f.write('\n'.join(lines) + '\n')
    return total


def write_md(path):
    from vdpview_doc import render_md
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(render_md(PAGES))


def main():
    build_edge_pages()
    build_color_pages()
    build_raster_pages()
    if 'build_v9968_pages' in globals():
        build_v9968_pages()
    build_yjk_pages()
    build_sc8_sp3_page()
    total = write_inc(os.path.join(HERE, 'VDPVIEW.INC'))
    for i, p in enumerate(PAGES):
        print('%2d %-28s %6d bytes' % (i + 1, p.title, p.size))
    print('total %d bytes' % total)
    if os.path.exists(os.path.join(HERE, 'vdpview_doc.py')):
        sys.path.insert(0, HERE)
        write_md(os.path.join(HERE, 'VDPVIEW.md'))
        os.makedirs(os.path.join(HERE, 'img'), exist_ok=True)
        for i, p in enumerate(PAGES):
            if hasattr(p, 'expect'):
                p.expect().save(os.path.join(HERE, 'img', 'p%02d.png' % (i + 1)))


# --- V9968: sprite mode 3 --------------------------------------------------------
def pal5_bytes(pal):
    out = []
    for r, g, b in pal:
        out += [r & 31, g & 31, b & 31]
    return out


def msx_to5(rgb):
    return tuple((v << 2) | (v >> 1) for v in rgb)


class Sprite3:
    def __init__(self, x, y, tile, mgx=16, mgy=16, rvx=0, rvy=0, tp=0, ps=0):
        self.x, self.y, self.tile = x, y, tile
        self.mgx, self.mgy, self.rvx, self.rvy, self.tp, self.ps = mgx, mgy, rvx, rvy, tp, ps


class SpriteSet3:
    """SP3, 16x16 tiles on the sheet at R#6 = 20h (10000h)."""
    SHEET = 0x10000

    def __init__(self, page, attr):
        self.page = page
        self.attr = attr
        self.tiles = {}
        self.sprites = []

    def tile(self, n, rows):
        """rows: 16 lists of 16 colour codes."""
        self.tiles[n] = rows
        v = self.page.scr.vram
        py, px = n >> 4, n & 15
        for y in range(16):
            a = self.SHEET + py * 2048 + y * 128 + px * 8
            for x in range(0, 16, 2):
                v[a + x // 2] = (rows[y][x] << 4) | rows[y][x + 1]

    def add(self, *a, **k):
        s = Sprite3(*a, **k)
        self.sprites.append(s)
        return s

    def write(self):
        v = self.page.scr.vram
        for i, s in enumerate(self.sprites):
            a = self.attr + i * 8
            y = (s.y - 1) & 1023
            x = s.x & 1023
            assert y != 216
            v[a:a + 8] = bytes([y & 255, y >> 8, s.mgy & 255,
                                (s.tp << 6) | (s.rvy << 5) | (s.rvx << 4) | s.ps,
                                x & 255, x >> 8, s.mgx & 255, s.tile])
        v[self.attr + len(self.sprites) * 8] = 216

    def render(self):
        """(x, y) -> (palette number, tp) of the top most plane."""
        out = {}
        for s in self.sprites:
            mgy = s.mgy or 256
            mgx = s.mgx or 256
            rows = self.tiles[s.tile]
            for line in range(self.page.lines):
                off = (line - s.y) & 1023
                if off >= mgy:
                    continue
                r = off * 16 // mgy
                if s.rvy:
                    r = 15 - r
                for d in range(mgx):
                    c = d * 16 // mgx
                    if s.rvx:
                        c = 15 - c
                    code = rows[r][c]
                    x = (s.x + d) & 1023
                    if code == 0 or x > 255 or (x, line) in out:
                        continue
                    out[(x, line)] = ((s.ps << 4) | code, s.tp)
        return out


def shape_tile(code):
    p = make_pattern(16)
    return [[code if p[y] & (0x8000 >> x) else 0 for x in range(16)] for y in range(16)]


def color_tile():
    rows = []
    for y in range(16):
        row = []
        for x in range(16):
            c = [2, 7, 10, 13][x // 4] if y < 12 else [5, 9][x // 8]
            if x - y > 11:
                c = 0
            row.append(c)
        rows.append(row)
    return rows


def blend5(sp, bg, tp):
    return tuple([s5, (3 * s5 + b5) >> 2, (s5 + b5) >> 1, (s5 + 3 * b5) >> 2][tp]
                 for s5, b5 in zip(sp, bg))


def expect_image(p, pal5, sprites):
    """Expected display (640x480 like the openMSX shots) from the page model.
    pal5: 5 bit RGB palette; sprites: (x, y) -> (palette number, tp)."""
    from PIL import Image
    to8 = lambda c: tuple(v * 255 // 31 for v in c)
    img = Image.new('RGB', (320, 240), to8(pal5[p.r7]))
    top = (240 - p.lines) // 2
    v = p.scr.vram
    for y in range(p.lines):
        for x in range(256):
            if p.mode == 'G4':
                b = v[y * 128 + (x >> 1)]
                c = (b & 15) if x & 1 else (b >> 4)
            else:
                c = v[y * 256 + x]
            rgb = pal5[c]
            if (x, y) in sprites:
                pn, tp = sprites[(x, y)]
                rgb = blend5(pal5[pn], rgb, tp)
            img.putpixel((32 + x, top + y), to8(rgb))
    return img.resize((640, 480), Image.NEAREST)


def build_v9968_pages():
    # SCREEN 5 + sprite mode 3: edges, scaling, flips
    p = page('V9968 SC5 SPRITE MODE3', 'G4', v9968=True)
    p.r20 = 0x08
    p.r7 = 0
    p.regs = [(0, 0x06), (2, 0x1F), (5, 0xEF), (11, 0x00), (6, 0x20)]
    ss = SpriteSet3(p, 0x7600)
    ss.tile(0, shape_tile(15))
    ss.tile(1, color_tile())
    h = p.lines
    for x, y in [(-8, -8), (100, -8), (248, -8), (-8, 60), (248, 60),
                 (-8, h - 8), (100, h - 8), (248, h - 8)]:
        ss.add(x, y, 0)
    # power of two sizes only: other sizes use an approximate reciprocal in the RTL
    ss.add(24, 60, 0, mgx=32, mgy=32)
    ss.add(64, 60, 0, mgx=8, mgy=8)
    ss.add(80, 60, 0, rvx=1)
    ss.add(104, 60, 0, rvy=1)
    ss.add(128, 60, 0, rvx=1, rvy=1)
    ss.add(152, 60, 0, mgx=64, mgy=16)
    ss.add(224, 60, 0, mgx=8, mgy=32)
    img = ss.render()
    ss.add(24, 110, 1)
    ss.add(48, 110, 1, mgx=32, mgy=32)
    ss.add(88, 110, 1, rvx=1)
    ss.add(112, 110, 1, mgx=64, mgy=16)
    ss.add(184, 110, 1, rvy=1)
    ss.write()
    swatch = {k: pn for k, (pn, tp) in ss.render().items() if k not in img}
    for (x, y) in img:
        p.scr.dot(x, y, RED)
    for (x, y), pn in swatch.items():
        p.scr.dot(x, y + 40, pn)
    p.scr.text(40, 22, 'V9968 SC5 SPRITE MODE3', 11)
    p.scr.text(40, 32, 'NO RED, SPRITE = SWATCH', 11)
    pal = [msx_to5(MSX2_PALETTE[i]) for i in range(16)]
    p.expect = lambda p=p, pal=pal, sp=ss.render(): expect_image(p, pal, sp)
    p.doc = 'V9968: SCREEN 5 + スプライトモード3（上下左右の端、x2/x0.5/64x16/8x32 の拡縮、RVX/RVY、ドットごとの色）'

    # SCREEN 8 + EPAL: palette sets of sprite mode 2, border as palette number
    p = page('V9968 SC8 EPAL PALETTE SET', 'G7', v9968=True)
    p.r20 = 0x10
    pal = []
    for n in range(256):
        s, c = n >> 4, n & 15
        hue = [(31, 0, 0), (31, 16, 0), (31, 31, 0), (16, 31, 0), (0, 31, 0), (0, 31, 16),
               (0, 31, 31), (0, 16, 31), (0, 0, 31), (16, 0, 31), (31, 0, 31), (31, 0, 16),
               (31, 31, 31), (24, 16, 8), (8, 16, 24), (16, 16, 16)][s]
        pal.append(tuple(v * (c + 1) // 16 for v in hue))
    p.palette = pal5_bytes(pal)
    p.r7 = 0xC9
    p.fill(0, 0, 8, 212, 0xC9)
    p.fill(248, 0, 8, 212, 0xC9)
    ss = SpriteSet(p, 2, 16, 1)
    ss.patterns[0] = SOLID16
    for i in range(16):
        x = 16 + (i & 7) * 28
        y = 60 if i < 8 else 120
        ss.add(x, y, color=[15] * 6 + [9] * 5 + [3] * 5)
    ss.write()
    t = SPR_TABLES['G7']
    for i in range(16):
        p.scr.vram[t['attr'] + i * 4 + 3] = i
    for i, s in enumerate(ss.sprites):
        for r0, n, c in ((0, 6, 15), (6, 5, 9), (11, 5, 3)):
            p.fill(s.x, s.y + 18 + r0, 16, n, (i << 4) | c)
    p.scr.text(16, 22, 'V9968 SC8 EPAL PALETTE SET', 0xCF)
    p.scr.text(16, 32, 'NO SEAM, SPRITE = SWATCH', 0xCF)
    spx = {}
    for i, s in enumerate(ss.sprites):
        for r in range(16):
            for d in range(16):
                spx[(s.x + d, s.y + r)] = ((i << 4) | s.color[r], 0)
    p.expect = lambda p=p, pal=pal, sp=spx: expect_image(p, pal, sp)
    p.doc = 'V9968: SCREEN 8 + EPAL=1（スプライトモード2のパレットセット0〜15、R#7 をパレット番号として表示）'

    # SCREEN 8 + EPAL + sprite mode 3: translucency
    p = page('V9968 SC8 SPRITE TRANSLUCENT', 'G7', v9968=True)
    p.r20 = 0x18
    p.r7 = 0
    p.regs = [(0, 0x0E), (2, 0x1F), (5, 0xF7), (11, 0x01), (6, 0x20)]
    pal = [(0, 0, 0)] * 256
    bgs = [(31, 0, 0), (0, 31, 0), (0, 0, 31), (31, 31, 31)]
    for i, c in enumerate(bgs):
        pal[1 + i] = c
    pal[15] = (31, 31, 0)
    spr = [(0, 31, 31), (31, 0, 31)]
    pal[0x21] = spr[0]
    pal[0x32] = spr[1]
    for si, sc in enumerate(spr):
        for bi, bc in enumerate(bgs):
            for tp in range(4):
                mix = []
                for s5, b5 in zip(sc, bc):
                    mix.append([s5, (3 * s5 + b5) >> 2, (s5 + b5) >> 1, (s5 + 3 * b5) >> 2][tp])
                pal[0x40 + si * 16 + bi * 4 + tp] = tuple(mix)
    p.palette = pal5_bytes(pal)
    ss = SpriteSet3(p, 0xFA00)
    ss.tile(0, [[1] * 16 for _ in range(16)])
    ss.tile(1, [[2] * 16 for _ in range(16)])
    for si in range(2):
        y = 50 + si * 80
        for tp in range(4):
            x = 16 + tp * 60
            for bi in range(4):
                p.fill(x + bi * 12, y - 6, 12, 44, 1 + bi)
                p.fill(x + bi * 12, y + 40, 12, 16, 0x40 + si * 16 + bi * 4 + tp)
            ss.add(x, y, si, mgx=48, mgy=32, tp=tp, ps=2 + si)
            p.scr.text(x + 12, y - 16, 'TP%d' % tp, 15)
    ss.write()
    p.scr.text(16, 4, 'V9968 SC8 TRANSLUCENT', 15)
    p.scr.text(16, 196, 'SPRITE = SWATCH BELOW', 15)
    p.expect = lambda p=p, pal=pal, sp=ss.render(): expect_image(p, pal, sp)
    p.doc = 'V9968: SCREEN 8 + EPAL=1 + スプライトモード3 の半透明 TP0〜3（背景4色との合成）とパレットセット'


# SCREEN 8 fixed sprite colours (G, R, B) and the 5 bit expansion of GRB332
SC8_SPRITE_GRB = [(0, 0, 0), (0, 0, 1), (0, 3, 0), (0, 3, 1), (3, 0, 0), (3, 0, 1), (3, 3, 0), (3, 3, 1),
                  (4, 7, 1), (0, 0, 3), (0, 7, 0), (0, 7, 3), (7, 0, 0), (7, 0, 3), (7, 7, 0), (7, 7, 3)]


def grb332_to5(g, r, b):
    e3 = lambda v: (v << 2) | (v >> 1)
    return (e3(r), e3(g), [0, 9, 18, 31][b])


def build_sc8_sp3_page():
    # SCREEN 8 (EPAL=0) + sprite mode 3: fixed 16 colours, palette set ignored,
    # TP0-3 blended with the GRB332 background. The background/sprite pairs are
    # chosen so that every blend is exactly a GRB332 colour (swatch = exact result).
    p = page('V9968 SC8 SP3 FIXED COLOR', 'G7', v9968=True)
    p.r20 = 0x08
    p.r7 = 0
    p.regs = [(0, 0x0E), (2, 0x1F), (5, 0xF7), (11, 0x01), (6, 0x20)]
    pal5 = [grb332_to5(c >> 5, (c >> 2) & 7, c & 3) for c in range(256)]
    pal5 += [grb332_to5(*SC8_SPRITE_GRB[c]) for c in range(16)]
    to332 = {v: c for c, v in enumerate(pal5[:256])}
    ss = SpriteSet3(p, 0xFA00)
    rows = [(10, 0x9C), (12, 0xF0), (9, 0x93), (8, 0x1D)]
    for ri, (code, bg) in enumerate(rows):
        ss.tile(ri, [[code] * 16 for _ in range(16)])
        y = 26 + ri * 44
        p.fill(8, y - 6, 240, 40, bg)
        for tp in range(4):
            x = 16 + tp * 60
            mix = to332[blend5(pal5[256 + code], pal5[bg], tp)]
            p.fill(x, y + 16, 48, 12, mix)
            ss.add(x, y, ri, mgx=48, mgy=16, tp=tp, ps=1 + ri * 4 + tp)
    for tp in range(4):
        p.scr.text(16 + tp * 60 + 12, 12, 'TP%d' % tp, 0xFF)
    ss.write()
    p.scr.text(16, 2, 'V9968 SC8 SP3 FIXED', 0xFF)
    p.scr.text(16, 196, 'SPRITE = SWATCH BELOW', 0xFF)
    spx = {k: (256 + (pn & 15), tp) for k, (pn, tp) in ss.render().items()}
    p.expect = lambda p=p, pal=pal5, sp=spx: expect_image(p, pal, sp)
    p.doc = ('V9968: SCREEN 8（EPAL=0）+ スプライトモード3。固定16色（パレットセット指定は無視）と、'
             'GRB332 背景との半透明 TP0〜3')


if __name__ == '__main__':
    main()
