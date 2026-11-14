#!/usr/bin/env python3
# -----------------------------------------------------------------------------
#	gen_vdpchk.py -- test script generator for VDPCHK.COM
#
#	Builds the byte-code script executed by VDPCHK.ASM (and by the RTL bench
#	fpga/.../src/v9968/test_vdpchk), the expected CRC of every test, and
#	test_item.md.  The expected values come from a reference model of the
#	V9958 command engine that follows openMSX (VDPCmdEngine.cc, verified
#	against real hardware) and the V9938/V9958 data books.
#
#	Outputs (this folder):
#		VDPCHK.INC		script + tables for zma
#		vdpchk.hex		the same script, one byte per line ($readmemh)
#		vdpchk_expect.txt	expected log bytes of every test (debug aid)
#		test_item.md		numbered test items
# -----------------------------------------------------------------------------
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
#	script op codes (keep in sync with VDPCHK.ASM and test_vdpchk/tb.sv)
# ---------------------------------------------------------------------------
OP_END, OP_TEST, OP_CHECK, OP_REG, OP_P4, OP_CMD, OP_WAITCE, OP_FEED, OP_DRAIN, \
	OP_STAT, OP_FILLP, OP_FILLC, OP_READ, OP_CPUW, OP_CPUR, OP_SECTION = range(16)

# ---------------------------------------------------------------------------
#	pattern table and CRC-16/CCITT (poly 1021h, init FFFFh)
# ---------------------------------------------------------------------------
_r = random.Random(0x9968)
PAT = list(range(256))
_r.shuffle(PAT)

CRC_T = []
for _i in range(256):
	_c = _i << 8
	for _ in range(8):
		_c = ((_c << 1) ^ 0x1021) if (_c & 0x8000) else (_c << 1)
	CRC_T.append(_c & 0xFFFF)


def crc16(data):
	crc = 0xFFFF
	for b in data:
		crc = ((crc << 8) & 0xFFFF) ^ CRC_T[((crc >> 8) ^ b) & 0xFF]
	return crc


def pat_byte(a, seed):
	p = a >> 8
	off = ((p & 0xFF) * 0x4D + (p >> 8) * 0x9B + seed) & 0xFF
	return PAT[((a & 0xFF) + off) & 0xFF]


# ---------------------------------------------------------------------------
#	screen modes
# ---------------------------------------------------------------------------
class Mode:
	def __init__(self, name, disp, r0, r1, r25=0, cmd=False, fg4=False):
		self.name = name
		self.disp = disp			# T1 T2 G1 G2 MC G3 G4 G5 G6 G7
		self.r0 = r0
		self.r1 = r1
		self.r25 = r25 | (0x40 if cmd else 0)
		self.cmd = cmd
		self.fg4 = fg4
		if fg4 and (cmd or disp in ('G4', 'G5', 'G6', 'G7')):
			self.geom = 'G4'
		elif fg4:
			self.geom = None
		elif disp in ('G4', 'G5', 'G6', 'G7'):
			self.geom = disp
		elif cmd:
			self.geom = 'NB'
		else:
			self.geom = None
		self.ilv = disp in ('G6', 'G7')			# SP3 is always 0 here
		self.wrap14 = disp in ('T1', 'G1', 'G2', 'MC')

	def key(self):
		return (self.r0, self.r1, self.r25, self.fg4)


def M(name, disp, r0, r1, r25=0, **kw):
	return Mode(name, disp, r0, r1, r25, **kw)


BASE = {
	'SCREEN0(W40)': ('T1', 0x00, 0x50, 0x00),
	'SCREEN0(W80)': ('T2', 0x04, 0x50, 0x00),
	'SCREEN1': ('G1', 0x00, 0x40, 0x00),
	'SCREEN2': ('G2', 0x02, 0x40, 0x00),
	'SCREEN3': ('MC', 0x00, 0x48, 0x00),
	'SCREEN4': ('G3', 0x04, 0x40, 0x00),
	'SCREEN5': ('G4', 0x06, 0x40, 0x00),
	'SCREEN6': ('G5', 0x08, 0x40, 0x00),
	'SCREEN7': ('G6', 0x0A, 0x40, 0x00),
	'SCREEN8': ('G7', 0x0E, 0x40, 0x00),
	'SCREEN10': ('G7', 0x0E, 0x40, 0x18),
	'SCREEN11': ('G7', 0x0E, 0x40, 0x18),
	'SCREEN12': ('G7', 0x0E, 0x40, 0x08),
}


def mode(name, cmd=False, fg4=False):
	d, r0, r1, r25 = BASE[name]
	label = name + (' CMD=1' if cmd else '') + (' FG4=1' if fg4 else '')
	return Mode(label, d, r0, r1, r25, cmd=cmd, fg4=fg4)


GEOM = {
	'G4': (256, 1, 0x0F, 128),
	'G5': (512, 2, 0x03, 128),
	'G6': (512, 1, 0x0F, 256),
	'G7': (256, 0, 0xFF, 256),
	'NB': (256, 0, 0xFF, 256),
}

DIX, DIY, EQ, MAJ = 0x04, 0x08, 0x02, 0x01
LOPS = {'IMP': 0, 'AND': 1, 'OR': 2, 'XOR': 3, 'NOT': 4,
	'TIMP': 8, 'TAND': 9, 'TOR': 10, 'TXOR': 11, 'TNOT': 12}
C_POINT, C_PSET, C_SRCH, C_LINE, C_LMMV, C_LMMM, C_LMCM, C_LMMC, \
	C_HMMV, C_HMMM, C_YMMM, C_HMMC = 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xA0, 0xB0, \
	0xC0, 0xD0, 0xE0, 0xF0
CNAME = {0x40: 'POINT', 0x50: 'PSET', 0x60: 'SRCH', 0x70: 'LINE', 0x80: 'LMMV', 0x90: 'LMMM',
	0xA0: 'LMCM', 0xB0: 'LMMC', 0xC0: 'HMMV', 0xD0: 'HMMM', 0xE0: 'YMMM', 0xF0: 'HMMC'}


class UnknownRead(Exception):
	pass


# ---------------------------------------------------------------------------
#	reference model of the command engine (openMSX VDPCmdEngine semantics)
# ---------------------------------------------------------------------------
class Engine:
	def __init__(self, gen, dry=False):
		self.g = gen
		self.dry = dry
		self.rows = set()

	# --- VRAM access through the logical -> physical mapping of the display mode
	def rd(self, a):
		a &= 0x1FFFF
		if self.dry:
			self.rows.add(a)
			return self.g.vram[self.g.phys(a)] if self.g.known[self.g.phys(a)] else 0
		return self.g.rd(a)

	def wr(self, a, v):
		a &= 0x1FFFF
		if self.dry:
			self.rows.add(a)
			return
		self.g.wr(a, v)

	def addr(self, x, y):
		k = self.geom
		if k == 'G4':
			return ((y & 1023) << 7) | ((x & 255) >> 1)
		if k == 'G5':
			return ((y & 1023) << 7) | ((x & 511) >> 2)
		if k == 'G6':
			return ((y & 511) << 8) | ((x & 511) >> 1)
		return ((y & 511) << 8) | (x & 255)

	def point(self, x, y):
		b = self.rd(self.addr(x, y))
		if self.geom in ('G4', 'G6'):
			return (b >> (((~x) & 1) << 2)) & 15
		if self.geom == 'G5':
			return (b >> (((~x) & 3) << 1)) & 3
		return b

	def pset(self, x, y, color, lop):
		a = self.addr(x, y)
		src = self.rd(a)
		if self.geom in ('G4', 'G6'):
			sh = ((~x) & 1) << 2
			col = (color << sh) & 0xFF
			mask = (~(15 << sh)) & 0xFF
		elif self.geom == 'G5':
			sh = ((~x) & 3) << 1
			col = (color << sh) & 0xFF
			mask = (~(3 << sh)) & 0xFF
		else:
			col = color
			mask = 0
		op = lop & 7
		if (lop & 8) and col == 0:
			return
		if op == 0:
			v = (src & mask) | col
		elif op == 1:
			v = src & (col | mask)
		elif op == 2:
			v = src | col
		elif op == 3:
			v = src ^ col
		elif op == 4:
			v = (src & mask) | (~(col | mask) & 0xFF)
		else:
			raise ValueError('undefined logical operation')
		self.wr(a, v & 0xFF)

	# --- clipping (openMSX)
	def clip1p(self, dx, nx, arg):
		if dx >= self.ppl:
			return 1
		nx = nx if nx else self.ppl
		return min(nx, dx + 1) if arg & DIX else min(nx, self.ppl - dx)

	def clip1b(self, dx, nx, arg):
		bpl = self.ppl >> self.sh
		dx >>= self.sh
		if bpl <= dx:
			return 1
		nx >>= self.sh
		nx = nx if nx else bpl
		return min(nx, dx + 1) if arg & DIX else min(nx, bpl - dx)

	def clip2p(self, sx, dx, nx, arg):
		if sx >= self.ppl or dx >= self.ppl:
			return 1
		nx = nx if nx else self.ppl
		return min(nx, min(sx, dx) + 1) if arg & DIX else min(nx, self.ppl - max(sx, dx))

	def clip2b(self, sx, dx, nx, arg):
		bpl = self.ppl >> self.sh
		sx >>= self.sh
		dx >>= self.sh
		if bpl <= sx or bpl <= dx:
			return 1
		nx >>= self.sh
		nx = nx if nx else bpl
		return min(nx, min(sx, dx) + 1) if arg & DIX else min(nx, bpl - max(sx, dx))

	@staticmethod
	def clipy1(dy, ny, arg):
		ny = ny if ny else 1024
		return min(ny, dy + 1) if arg & DIY else ny

	@staticmethod
	def clipy2(sy, dy, ny, arg):
		ny = ny if ny else 1024
		return min(ny, min(sy, dy) + 1) if arg & DIY else ny

	# --- command execution.  Returns a list of status/transfer bytes to log.
	def run(self, geom, r, data):
		self.geom = geom
		self.ppl, self.sh, self.cmask, _ = GEOM[geom]
		sx, sy = r['sx'] & 0x1FF, r['sy'] & 0x3FF
		dx, dy = r['dx'] & 0x1FF, r['dy'] & 0x3FF
		nx, ny = r['nx'] & 0x3FF, r['ny'] & 0x3FF
		clr, arg, cmd = r['clr'], r['arg'], r['cmd']
		c = cmd & 0xF0
		lop = cmd & 0x0F
		tx = -1 if arg & DIX else 1
		ty = -1 if arg & DIY else 1
		ppb = 1 << self.sh
		res = {'col': None, 'asx': None, 'bd': False, 'lmcm': []}
		col = clr & self.cmask
		if c == C_POINT:
			res['col'] = self.point(sx, sy)
		elif c == C_PSET:
			self.pset(dx, dy, col, lop)
		elif c == C_SRCH:
			asx = sx
			while True:
				p = self.point(asx, sy)
				if (p == col) ^ bool(arg & EQ):
					res['bd'] = True
					break
				asx += tx
				if asx & self.ppl:
					break
			res['asx'] = asx
		elif c == C_LINE:
			asx = ((nx - 1) & 0xFFFFFFFF) >> 1
			adx, anx = dx, 0
			while True:
				self.pset(adx, dy, col, lop)
				if not (arg & MAJ):
					adx += tx
					stop = anx == nx
					anx += 1
					if stop or (adx & self.ppl):
						break
					if asx < ny:
						asx += nx
						dy += ty
						if ty < 0 and dy < 0:
							break
					asx = (asx - ny) & 1023
				else:
					dy += ty
					if ty < 0 and dy < 0:
						break
					if asx < ny:
						asx += nx
						adx += tx
					asx = (asx - ny) & 1023
					stop = anx == nx
					anx += 1
					if stop or (adx & self.ppl):
						break
		elif c in (C_LMMV, C_LMMC):
			tnx = self.clip1p(dx, nx, arg)
			tny = self.clipy1(dy, ny, arg)
			k = 0
			for _ in range(tny):
				adx = dx
				for _ in range(tnx):
					if c == C_LMMV:
						self.pset(adx, dy, col, lop)
					else:
						self.pset(adx, dy, data(k) & self.cmask, lop)
						k += 1
					adx += tx
				dy += ty
		elif c == C_LMMM:
			tnx = self.clip2p(sx, dx, nx, arg)
			tny = self.clipy2(sy, dy, ny, arg)
			for _ in range(tny):
				asx, adx = sx, dx
				for _ in range(tnx):
					self.pset(adx, dy, self.point(asx, sy), lop)
					asx += tx
					adx += tx
				sy += ty
				dy += ty
		elif c == C_LMCM:
			tnx = self.clip1p(sx, nx, arg)
			tny = self.clipy1(sy, ny, arg)
			for _ in range(tny):
				asx = sx
				for _ in range(tnx):
					res['lmcm'].append(self.point(asx, sy))
					asx += tx
				sy += ty
			res['col'] = res['lmcm'][-1]
		elif c in (C_HMMV, C_HMMC):
			tnx = self.clip1b(dx, nx, arg)
			tny = self.clipy1(dy, ny, arg)
			k = 0
			for _ in range(tny):
				adx = dx
				for _ in range(tnx):
					if c == C_HMMV:
						self.wr(self.addr(adx, dy), clr)
					else:
						self.wr(self.addr(adx, dy), data(k))
						k += 1
					adx += tx * ppb
				dy += ty
		elif c == C_HMMM:
			tnx = self.clip2b(sx, dx, nx, arg)
			tny = self.clipy2(sy, dy, ny, arg)
			for _ in range(tny):
				asx, adx = sx, dx
				for _ in range(tnx):
					self.wr(self.addr(adx, dy), self.rd(self.addr(asx, sy)))
					asx += tx * ppb
					adx += tx * ppb
				sy += ty
				dy += ty
		elif c == C_YMMM:
			tnx = self.clip1b(dx, 512, arg)
			tny = self.clipy2(sy, dy, ny, arg)
			for _ in range(tny):
				adx = dx
				for _ in range(tnx):
					self.wr(self.addr(adx, dy), self.rd(self.addr(adx, sy)))
					adx += tx * ppb
				sy += ty
				dy += ty
		else:
			raise ValueError('unsupported command %02X' % cmd)
		return res


# ---------------------------------------------------------------------------
#	script generator
# ---------------------------------------------------------------------------
class Gen:
	def __init__(self):
		self.code = bytearray()
		self.items = []			# (kind, ...) for test_item.md
		self.expect = []
		self.num = 0
		self.vram = bytearray(0x20000)
		self.known = bytearray(0x20000)
		self.mode = None
		self.cur_key = None
		self.ext = False
		self.bd = False
		self.col = 0
		self.log = None
		self.sec = None
		self.group = ''
		self.seed = 0x31

	# --- low level emit
	def b(self, *v):
		for x in v:
			self.code.append(x & 0xFF)

	def w(self, v):
		self.b(v & 0xFF, (v >> 8) & 0xFF)

	def a24(self, v):
		self.b(v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF)

	# --- VRAM model
	def phys(self, a):
		a &= 0x1FFFF
		if self.mode is not None and self.mode.ilv:
			return ((a & 1) << 16) | (a >> 1)
		return a

	def rd(self, a):
		p = self.phys(a)
		if not self.known[p]:
			raise UnknownRead('test %d reads unknown VRAM %05X' % (self.num, a))
		return self.vram[p]

	def wr(self, a, v):
		p = self.phys(a)
		self.vram[p] = v & 0xFF
		self.known[p] = 1

	# --- structure
	def section(self, title, v9968_only=False):
		self.end_section()
		self.items.append(('section', title, v9968_only))
		self.b(OP_SECTION, 1 if v9968_only else 0)
		self.sec = (len(self.code), self.num, v9968_only)
		self.w(0)
		self.w(0)
		self.cur_key = None
		self.ext = v9968_only

	def end_section(self):
		if self.sec is None:
			return
		pos, first, ext = self.sec
		if ext:
			# back to the V9958 compatible mode, extended registers locked
			self.reg(20, 0x00)
			self.reg(21, 0x01)
			self.b(OP_P4, 0x80)
		n = self.num - first
		ln = len(self.code) - (pos + 4)
		self.code[pos:pos + 2] = bytes((n & 0xFF, n >> 8))
		self.code[pos + 2:pos + 4] = bytes((ln & 0xFF, ln >> 8))
		self.sec = None
		self.cur_key = None

	def sub(self, title):
		self.group = title
		self.items.append(('group', title))

	def reg(self, r, v):
		self.b(OP_REG, r, v)

	def set_mode(self, m):
		self.mode = m
		if self.cur_key == m.key():
			return
		if self.ext and self.cur_key is None:
			self.b(OP_P4, 0x00)		# unlock R#20/R#21
			self.reg(21, 0x00)		# V58=0: extended mode (FG4 usable)
			self.reg(20, 0x00)
		self.reg(0, m.r0)
		self.reg(1, m.r1)
		self.reg(8, 0x0A)			# VR=1, sprites off
		self.reg(9, 0x00)
		self.reg(25, m.r25)
		self.reg(23, 0x00)
		self.cur_key = m.key()

	def begin(self, desc, m):
		if m.fg4:
			assert self.ext
		self.num += 1
		self.set_mode(m)
		self.b(OP_TEST)
		self.w(self.num)
		self.known[:] = bytes(len(self.known))
		self.log = []
		self.desc = desc
		self.seed = (self.num * 0x2F + 0x13) & 0xFF

	def end(self):
		c = crc16(self.log)
		self.b(OP_CHECK)
		self.w(c)
		self.items.append(('test', self.num, self.mode.name, self.group, self.desc))
		self.expect.append((self.num, list(self.log)))
		self.log = None

	# --- memory ops
	def fillp(self, a, n, seed=None):
		seed = self.seed if seed is None else seed
		assert 0 < n <= 0x10000 and a + n <= 0x20000
		self.b(OP_FILLP)
		self.a24(a)
		self.w(n & 0xFFFF)
		self.b(seed)
		for i in range(n):
			self.wr(a + i, pat_byte(a + i, seed))

	def fillc(self, a, n, v):
		assert 0 < n <= 0x10000 and a + n <= 0x20000
		self.b(OP_FILLC)
		self.a24(a)
		self.w(n & 0xFFFF)
		self.b(v)
		for i in range(n):
			self.wr(a + i, v)

	def read(self, a, n):
		assert 0 < n <= 0x10000 and a + n <= 0x20000
		self.b(OP_READ)
		self.a24(a)
		self.w(n & 0xFFFF)
		for i in range(n):
			self.log.append(self.rd(a + i))

	def fill_regions(self, regs):
		for a, n in regs:
			while n:
				k = min(n, 0x10000)
				self.fillp(a, k)
				a += k
				n -= k

	def read_regions(self, regs):
		for a, n in regs:
			while n:
				k = min(n, 0x10000)
				self.read(a, k)
				a += k
				n -= k

	def cpu_next(self, a):
		if self.mode.wrap14:
			return (a & 0x1C000) | ((a + 1) & 0x3FFF)
		return (a + 1) & 0x1FFFF

	def cpuw(self, a, n, seed):
		assert 0 < n <= 0x4000
		self.b(OP_CPUW)
		self.a24(a)
		self.w(n)
		self.b(seed)
		for k in range(n):
			self.wr(a, PAT[(seed + k) & 0xFF])
			a = self.cpu_next(a)

	def cpur(self, a, n):
		assert 0 < n <= 0x4000
		self.b(OP_CPUR)
		self.a24(a)
		self.w(n)
		for _ in range(n):
			self.log.append(self.rd(a))
			a = self.cpu_next(a)

	def stat(self, n, mask, value=None):
		self.b(OP_STAT, n, mask)
		if mask:
			self.log.append(value & mask)

	# --- command
	def rowbytes(self):
		return GEOM[self.mode.geom][3] if self.mode.geom else 256

	def regions_of(self, addrs, margin=1):
		rb = self.rowbytes()
		nrows = 0x20000 // rb
		rows = set()
		for a in addrs:
			r = a // rb
			for d in range(-margin, margin + 1):
				rows.add((r + d) % nrows)
		regs = []
		for r in sorted(rows):
			if regs and regs[-1][0] + regs[-1][1] == r * rb:
				regs[-1][1] += rb
			else:
				regs.append([r * rb, rb])
		return [tuple(x) for x in regs]

	def cmd(self, c, sx=0, sy=0, dx=0, dy=0, nx=0, ny=0, clr=0, arg=0, autofill=True, check=True):
		m = self.mode
		seed = self.seed
		cc = c & 0xF0
		if cc in (C_LMMC, C_HMMC):
			clr = PAT[seed]
		r = dict(sx=sx, sy=sy, dx=dx, dy=dy, nx=nx, ny=ny, clr=clr, arg=arg, cmd=c)

		def data(k):
			return PAT[(seed + k) & 0xFF]
		regs = []
		if m.geom and autofill:
			dry = Engine(self, dry=True)
			dry.run(m.geom, r, data)
			regs = self.regions_of(dry.rows)
			self.fill_regions(regs)
		if cc == C_SRCH:
			self.stat(9, 0)					# clears BD
		if cc == C_LMCM:
			self.stat(7, 0)					# clears a stale TR
		arg_out = arg | (0x80 if m.fg4 else 0)
		self.b(OP_CMD, sx, sx >> 8, sy, sy >> 8, dx, dx >> 8, dy, dy >> 8,
			nx, nx >> 8, ny, ny >> 8, clr, arg_out, c)
		res = None
		if m.geom:
			res = Engine(self).run(m.geom, r, data)
		if cc in (C_LMMC, C_HMMC):
			self.b(OP_FEED, seed)
		elif cc == C_LMCM and res is not None:
			self.b(OP_DRAIN)
			self.log += res['lmcm']
			n = len(res['lmcm'])
			self.log += [n & 0xFF, n >> 8]
		else:
			self.b(OP_WAITCE)
		if cc == C_POINT:
			self.stat(7, 0xFF, res['col'])
		if cc == C_SRCH and res is not None:
			asx = res['asx']
			self.stat(2, 0x10, 0x10 if res['bd'] else 0)
			self.stat(8, 0xFF, asx & 0xFF)
			self.stat(9, 0xFF, 0xFE | ((asx >> 8) & 1))
			self.stat(2, 0x10, 0)
		if check and regs:
			self.read_regions(regs)
		return res

	def finish(self):
		self.end_section()
		self.b(OP_END)


# ---------------------------------------------------------------------------
#	test suites
# ---------------------------------------------------------------------------
def T(g, m, desc, c, **kw):
	g.begin(desc, m)
	g.cmd(c, **kw)
	g.end()


def dirs(arg):
	return 'DIX=%d DIY=%d' % (1 if arg & DIX else 0, 1 if arg & DIY else 0)


def suite_commands(g, m, level):
	"""level: 3 = full, 2 = standard, 1 = small"""
	W, sh, cm, _ = GEOM[m.geom]
	ppb = 1 << sh
	H = 1024 if m.geom in ('G4', 'G5') else 512
	wrap_ok = not m.fg4
	all_dirs = [0, DIX, DIY, DIX | DIY]
	cols = [0xA5, 0x3C, 0x5A, 0xC3, 0x96, 0x69, 0x0F, 0xF1, 0x7E, 0x18]

	# ---------------- HMMV
	g.sub('HMMV')
	T(g, m, 'HMMV 基本 (DX/NX 奇数)', C_HMMV, dx=W // 8 + 1, dy=30, nx=W // 4 + 3, ny=5, clr=0xA7)
	for a in (all_dirs if level >= 2 else [DIX | DIY]):
		T(g, m, 'HMMV 方向 ' + dirs(a), C_HMMV, dx=W // 2 + ppb, dy=60, nx=W // 5, ny=4, clr=0x5E, arg=a)
	T(g, m, 'HMMV 右端はみ出し', C_HMMV, dx=W - 3 * ppb - 1, dy=40, nx=10 * ppb, ny=3, clr=0x3C)
	T(g, m, 'HMMV 左端はみ出し DIX=1', C_HMMV, dx=2 * ppb + 1, dy=44, nx=10 * ppb, ny=3, clr=0xC3, arg=DIX)
	T(g, m, 'HMMV NX=0 (右端まで)', C_HMMV, dx=W // 4, dy=50, nx=0, ny=2, clr=0x66)
	if level >= 2:
		T(g, m, 'HMMV NX=0 DIX=1 (左端まで)', C_HMMV, dx=W // 4, dy=52, nx=0, ny=2, clr=0x99, arg=DIX)
		T(g, m, 'HMMV NX=1', C_HMMV, dx=W // 3, dy=54, nx=1, ny=2, clr=0x24)
	T(g, m, 'HMMV NY=0 DIY=1 (上端で停止)', C_HMMV, dx=8 * ppb, dy=3, nx=4 * ppb, ny=0, clr=0x81, arg=DIY)
	if level >= 2:
		T(g, m, 'HMMV 上端はみ出し DIY=1', C_HMMV, dx=8 * ppb, dy=2, nx=6 * ppb, ny=10, clr=0x42, arg=DIY)
	if wrap_ok and level >= 2:
		T(g, m, 'HMMV 下端から折り返し', C_HMMV, dx=16 * ppb, dy=H - 2, nx=6 * ppb, ny=4, clr=0x18)
	if level >= 3:
		T(g, m, 'HMMV NX=0 NY=0 (VRAM 全域)', C_HMMV, dx=0, dy=0, nx=0, ny=0, clr=0x5A)

	# ---------------- LMMV
	g.sub('LMMV')
	lops = list(LOPS.items()) if level >= 2 else [('IMP', 0), ('XOR', 3), ('TIMP', 8)]
	for i, (n, lo) in enumerate(lops):
		T(g, m, 'LMMV ' + n, C_LMMV | lo, dx=W // 8 + 1, dy=70 + i * 4, nx=W // 6 + 1, ny=3, clr=cols[i])
	T(g, m, 'LMMV TIMP 色0 (書かれない)', C_LMMV | 8, dx=11, dy=120, nx=W // 6, ny=2, clr=0x00)
	if level >= 2:
		T(g, m, 'LMMV IMP 色0', C_LMMV, dx=11, dy=124, nx=W // 6, ny=2, clr=0x00)
		T(g, m, 'LMMV TXOR 色0 (書かれない)', C_LMMV | 11, dx=11, dy=128, nx=W // 6, ny=2, clr=0x00)
	for a in (all_dirs if level >= 2 else [DIX | DIY]):
		T(g, m, 'LMMV 方向 ' + dirs(a), C_LMMV | 3, dx=W // 2 + 1, dy=140, nx=W // 5 + 1, ny=4, clr=0x6B, arg=a)
	T(g, m, 'LMMV 右端はみ出し', C_LMMV, dx=W - 5, dy=150, nx=12, ny=3, clr=0x2D)
	T(g, m, 'LMMV 左端はみ出し DIX=1', C_LMMV, dx=4, dy=154, nx=12, ny=3, clr=0xD2, arg=DIX)
	if level >= 2:
		T(g, m, 'LMMV NX=0', C_LMMV, dx=W - 37, dy=158, nx=0, ny=2, clr=0x4E)
		T(g, m, 'LMMV NY=0 DIY=1 (上端で停止)', C_LMMV | 2, dx=5, dy=2, nx=9, ny=0, clr=0x71, arg=DIY)
	if wrap_ok and level >= 2:
		T(g, m, 'LMMV 下端から折り返し', C_LMMV, dx=33, dy=H - 1, nx=9, ny=3, clr=0x1E)
	if level >= 3:
		T(g, m, 'LMMV DX>=幅 (1 ドットのみ)', C_LMMV, dx=W + 3 if W == 256 else 511, dy=162, nx=5, ny=2, clr=0x3A)

	# ---------------- LMMM
	g.sub('LMMM')
	lops = list(LOPS.items()) if level >= 2 else [('IMP', 0), ('TIMP', 8)]
	for i, (n, lo) in enumerate(lops):
		T(g, m, 'LMMM ' + n + ' (SX 奇数, DX 偶数)', C_LMMM | lo, sx=W // 8 + 1, sy=170 + i * 3, dx=W // 2 + 2,
			dy=200 + i * 3, nx=W // 6 + 1, ny=2)
	for a in (all_dirs if level >= 2 else [DIX | DIY]):
		T(g, m, 'LMMM 方向 ' + dirs(a), C_LMMM, sx=W // 3, sy=240, dx=W // 2 + 3, dy=250, nx=W // 6, ny=4, arg=a)
	T(g, m, 'LMMM 重なり 右へずらし DIX=0', C_LMMM, sx=20, sy=262, dx=23, dy=262, nx=W // 4, ny=2)
	T(g, m, 'LMMM 重なり 右へずらし DIX=1', C_LMMM, sx=20 + W // 4, sy=266, dx=23 + W // 4, dy=266, nx=W // 4, ny=2, arg=DIX)
	if level >= 2:
		T(g, m, 'LMMM 重なり 下へずらし DIY=0', C_LMMM, sx=30, sy=270, dx=30, dy=272, nx=W // 5, ny=5)
		T(g, m, 'LMMM 重なり 下へずらし DIY=1', C_LMMM, sx=30, sy=286, dx=30, dy=288, nx=W // 5, ny=5, arg=DIY)
	T(g, m, 'LMMM 転送元が右端はみ出し', C_LMMM, sx=W - 6, sy=300, dx=W // 3, dy=304, nx=15, ny=2)
	T(g, m, 'LMMM 転送先が右端はみ出し', C_LMMM, sx=W // 3, sy=308, dx=W - 7, dy=312, nx=15, ny=2)
	if level >= 2:
		T(g, m, 'LMMM 左端はみ出し DIX=1', C_LMMM, sx=W // 2, sy=316, dx=5, dy=320, nx=15, ny=2, arg=DIX)
		T(g, m, 'LMMM NX=0', C_LMMM, sx=W - 40, sy=324, dx=W - 45, dy=328, nx=0, ny=2)
		T(g, m, 'LMMM NY=0 DIY=1 (上端で停止)', C_LMMM, sx=40, sy=6, dx=70, dy=3, nx=9, ny=0, arg=DIY)
	if wrap_ok and level >= 3:
		T(g, m, 'LMMM 下端から折り返し', C_LMMM, sx=40, sy=H - 2, dx=80, dy=H - 3, nx=9, ny=5)

	# ---------------- HMMM
	g.sub('HMMM')
	T(g, m, 'HMMM 基本 (SX/DX 奇数)', C_HMMM, sx=W // 8 + 1, sy=340, dx=W // 2 + 3, dy=346, nx=W // 4 + 1, ny=4)
	for a in (all_dirs if level >= 2 else [DIX | DIY]):
		T(g, m, 'HMMM 方向 ' + dirs(a), C_HMMM, sx=W // 3, sy=352, dx=W // 2 + 2 * ppb, dy=362, nx=W // 6, ny=4, arg=a)
	T(g, m, 'HMMM 重なり 下へずらし DIY=0', C_HMMM, sx=10 * ppb, sy=372, dx=12 * ppb, dy=374, nx=W // 3, ny=6)
	if level >= 2:
		T(g, m, 'HMMM 重なり 上へずらし DIY=1', C_HMMM, sx=10 * ppb, sy=392, dx=12 * ppb, dy=390, nx=W // 3, ny=6, arg=DIY)
		T(g, m, 'HMMM 重なり 右へずらし DIX=1', C_HMMM, sx=W // 2, sy=400, dx=W // 2 + 2 * ppb, dy=400, nx=W // 3, ny=2, arg=DIX)
	T(g, m, 'HMMM 転送元が右端はみ出し', C_HMMM, sx=W - 3 * ppb, sy=404, dx=W // 4, dy=408, nx=8 * ppb, ny=2)
	T(g, m, 'HMMM 転送先が右端はみ出し', C_HMMM, sx=W // 4, sy=412, dx=W - 3 * ppb, dy=416, nx=8 * ppb, ny=2)
	if level >= 2:
		T(g, m, 'HMMM 左端はみ出し DIX=1', C_HMMM, sx=W // 2, sy=420, dx=3 * ppb, dy=424, nx=8 * ppb, ny=2, arg=DIX)
		T(g, m, 'HMMM NX=0', C_HMMM, sx=W // 2, sy=428, dx=W // 4, dy=432, nx=0, ny=2)
		T(g, m, 'HMMM NX=1', C_HMMM, sx=W // 2, sy=436, dx=W // 4, dy=440, nx=1, ny=2)
		T(g, m, 'HMMM NY=0 DIY=1 (上端で停止)', C_HMMM, sx=W // 2, sy=5, dx=W // 4, dy=2, nx=6 * ppb, ny=0, arg=DIY)

	# ---------------- YMMM
	g.sub('YMMM')
	for a in (all_dirs if level >= 2 else [0, DIX | DIY]):
		T(g, m, 'YMMM 方向 ' + dirs(a), C_YMMM, sy=450, dx=W // 3 + 1, dy=460, ny=4, arg=a)
	if level >= 2:
		T(g, m, 'YMMM 重なり 1 ライン下へ', C_YMMM, sy=470, dx=W // 2, dy=471, ny=5)
		T(g, m, 'YMMM NY=0 DIY=1 (上端で停止)', C_YMMM, sy=4, dx=W - 9 * ppb, dy=2, ny=0, arg=DIY)

	# ---------------- LMCM
	g.sub('LMCM')
	T(g, m, 'LMCM 基本', C_LMCM, sx=W // 8 + 1, sy=480, nx=7, ny=3)
	for a in (all_dirs if level >= 2 else [DIX | DIY]):
		T(g, m, 'LMCM 方向 ' + dirs(a), C_LMCM, sx=W // 2 + 1, sy=486, nx=5, ny=3, arg=a)
	T(g, m, 'LMCM 右端はみ出し', C_LMCM, sx=W - 4, sy=492, nx=9, ny=3)
	if level >= 2:
		T(g, m, 'LMCM 左端はみ出し DIX=1', C_LMCM, sx=3, sy=496, nx=9, ny=3, arg=DIX)
		T(g, m, 'LMCM NY=0 DIY=1 (上端で停止)', C_LMCM, sx=W // 4, sy=2, nx=4, ny=0, arg=DIY)

	# ---------------- LMMC
	g.sub('LMMC')
	for n in (['IMP', 'XOR', 'TIMP', 'NOT'] if level >= 2 else ['IMP', 'TIMP']):
		T(g, m, 'LMMC ' + n, C_LMMC | LOPS[n], dx=W // 8 + 1, dy=100, nx=7, ny=3)
	for a in ([DIX, DIY, DIX | DIY] if level >= 2 else [DIX | DIY]):
		T(g, m, 'LMMC 方向 ' + dirs(a), C_LMMC, dx=W // 2 + 1, dy=106, nx=6, ny=3, arg=a)
	T(g, m, 'LMMC 右端はみ出し', C_LMMC, dx=W - 3, dy=112, nx=8, ny=3)
	if level >= 2:
		T(g, m, 'LMMC 左端はみ出し DIX=1', C_LMMC, dx=2, dy=116, nx=8, ny=3, arg=DIX)

	# ---------------- HMMC
	g.sub('HMMC')
	T(g, m, 'HMMC 基本 (DX 奇数)', C_HMMC, dx=W // 8 + 1, dy=180, nx=8 * ppb, ny=3)
	for a in ([DIX, DIY, DIX | DIY] if level >= 2 else [DIX | DIY]):
		T(g, m, 'HMMC 方向 ' + dirs(a), C_HMMC, dx=W // 2, dy=186, nx=6 * ppb, ny=3, arg=a)
	T(g, m, 'HMMC 右端はみ出し', C_HMMC, dx=W - 3 * ppb, dy=192, nx=8 * ppb, ny=2)
	if level >= 2:
		T(g, m, 'HMMC 左端はみ出し DIX=1', C_HMMC, dx=2 * ppb, dy=196, nx=8 * ppb, ny=2, arg=DIX)

	# ---------------- PSET / POINT
	g.sub('PSET / POINT')
	pl = list(LOPS.items()) if level >= 2 else [('IMP', 0), ('XOR', 3)]
	for i, (n, lo) in enumerate(pl):
		T(g, m, 'PSET ' + n, C_PSET | lo, dx=(i * 37 + 3) % W, dy=210 + i, clr=cols[i])
	T(g, m, 'PSET 右端 X=%d' % (W - 1), C_PSET, dx=W - 1, dy=230, clr=0xE7)
	T(g, m, 'PSET 左端 X=0', C_PSET, dx=0, dy=231, clr=0x7E)
	for i, x in enumerate([0, 1, W - 1, W // 2 + 3][:4 if level >= 2 else 2]):
		T(g, m, 'POINT X=%d' % x, C_POINT, sx=x, sy=232 + i)

	# ---------------- LINE
	g.sub('LINE')
	for a in (all_dirs if level >= 2 else [0, DIX | DIY]):
		T(g, m, 'LINE X 主軸 ' + dirs(a), C_LINE, dx=W // 2, dy=130, nx=40, ny=13, clr=0x5C, arg=a)
		T(g, m, 'LINE Y 主軸 ' + dirs(a), C_LINE, dx=W // 2, dy=130, nx=40, ny=13, clr=0x3B, arg=a | MAJ)
	lines = [
		('LINE 45 度', dict(dx=20, dy=20, nx=30, ny=30, clr=0x47)),
		('LINE NY=0 (水平)', dict(dx=W // 4, dy=22, nx=50, ny=0, clr=0x7A)),
		('LINE NX=0 (1 点)', dict(dx=W // 3, dy=24, nx=0, ny=0, clr=0x29)),
		('LINE 浅い傾き 255:7', dict(dx=0, dy=26, nx=W - 1, ny=7, clr=0x63)),
		('LINE 右端で停止', dict(dx=W - 10, dy=40, nx=30, ny=9, clr=0x1F)),
		('LINE 左端で停止 DIX=1', dict(dx=8, dy=50, nx=30, ny=9, clr=0xF1, arg=DIX)),
		('LINE Y 主軸 上端で停止', dict(dx=40, dy=6, nx=20, ny=7, clr=0x35, arg=DIY | MAJ)),
		('LINE X 主軸 上端で停止', dict(dx=40, dy=2, nx=30, ny=10, clr=0x53, arg=DIY)),
		('LINE NY>NX (X 主軸指定)', dict(dx=60, dy=60, nx=5, ny=20, clr=0x6E)),
		('LINE XOR', dict(dx=70, dy=70, nx=33, ny=17, clr=0xFF, op=3)),
		('LINE TIMP 色0 (書かれない)', dict(dx=70, dy=90, nx=33, ny=17, clr=0x00, op=8)),
		('LINE Y 主軸 1:1 MAJ=1', dict(dx=90, dy=96, nx=12, ny=12, clr=0x2A, arg=MAJ)),
	]
	if level < 2:
		lines = lines[:2] + lines[4:6]
	for desc, kw in lines:
		op = kw.pop('op', 0)
		T(g, m, desc, C_LINE | op, **kw)
	if wrap_ok and level >= 2:
		T(g, m, 'LINE Y 主軸 下端から折り返し', C_LINE, dx=40, dy=H - 3, nx=10, ny=4, clr=0x4D, arg=MAJ)

	# ---------------- SRCH
	g.sub('SRCH')
	suite_srch(g, m, level)


def suite_mini(g, m):
	"""one or two tests per command"""
	W, sh, cm, _ = GEOM[m.geom]
	ppb = 1 << sh
	g.sub('全コマンド (簡易)')
	T(g, m, 'HMMV 基本', C_HMMV, dx=W // 8 + 1, dy=30, nx=W // 4 + 3, ny=5, clr=0xA7)
	T(g, m, 'HMMV 右端はみ出し DIY=1', C_HMMV, dx=W - 3 * ppb - 1, dy=40, nx=10 * ppb, ny=3, clr=0x3C, arg=DIY)
	T(g, m, 'LMMV XOR DIX=1', C_LMMV | 3, dx=W // 2 + 1, dy=140, nx=W // 5 + 1, ny=4, clr=0x6B, arg=DIX)
	T(g, m, 'LMMV TIMP', C_LMMV | 8, dx=W - 5, dy=150, nx=12, ny=3, clr=0x2D)
	T(g, m, 'LMMM DIX=1 DIY=1', C_LMMM, sx=W // 3, sy=240, dx=W // 2 + 3, dy=250, nx=W // 6, ny=4, arg=DIX | DIY)
	T(g, m, 'HMMM 基本 (SX/DX 奇数)', C_HMMM, sx=W // 8 + 1, sy=340, dx=W // 2 + 3, dy=346, nx=W // 4 + 1, ny=4)
	T(g, m, 'YMMM DIX=1', C_YMMM, sy=450, dx=W // 3 + 1, dy=460, ny=4, arg=DIX)
	T(g, m, 'LMCM 右端はみ出し', C_LMCM, sx=W - 4, sy=492, nx=9, ny=3)
	T(g, m, 'LMMC TIMP DIX=1', C_LMMC | 8, dx=W // 2 + 1, dy=106, nx=6, ny=3, arg=DIX)
	T(g, m, 'HMMC 基本 (DX 奇数)', C_HMMC, dx=W // 8 + 1, dy=180, nx=8 * ppb, ny=3)
	T(g, m, 'PSET OR', C_PSET | 2, dx=W - 1, dy=230, clr=0xE7)
	T(g, m, 'POINT X=1', C_POINT, sx=1, sy=233)
	T(g, m, 'LINE X 主軸', C_LINE, dx=W // 2, dy=130, nx=40, ny=13, clr=0x5C)
	T(g, m, 'LINE Y 主軸 DIX=1 DIY=1', C_LINE, dx=W // 2, dy=130, nx=40, ny=13, clr=0x3B, arg=DIX | DIY | MAJ)
	bg, tc = ((1, 2) if cm == 3 else (5, 9) if cm == 15 else (0x25, 0x9A))
	srch_case(g, m, 'SRCH 発見', 304, bg, [(37, tc)], W - 5, tc, DIX)
	srch_case(g, m, 'SRCH 未発見', 302, bg, [], 5, tc, 0)


def put_pixel_byte(g, m, y, x, bg, color):
	W, sh, cm, rb = GEOM[m.geom]
	e = Engine(g)
	e.geom = m.geom
	e.ppl, e.sh, e.cmask = W, sh, cm
	a = e.addr(x, y)
	v = g.vram[g.phys(a)]
	if m.geom in ('G4', 'G6'):
		s = ((~x) & 1) << 2
		v = (v & ~(15 << s) & 0xFF) | (color << s)
	elif m.geom == 'G5':
		s = ((~x) & 3) << 1
		v = (v & ~(3 << s) & 0xFF) | (color << s)
	else:
		v = color
	g.fillc(a, 1, v)


def srch_case(g, m, desc, y, bg, targets, sx, clr, arg):
	W, sh, cm, rb = GEOM[m.geom]
	e = Engine(g)
	e.geom, e.ppl, e.sh, e.cmask = m.geom, W, sh, cm
	g.begin(desc, m)
	rep = {0: bg, 1: bg * 0x11, 2: bg * 0x55}[sh] if m.geom != 'G6' else bg * 0x11
	a0 = e.addr(0, y)
	g.fillc(a0, rb, rep & 0xFF)
	for x, c in targets:
		put_pixel_byte(g, m, y, x, bg, c)
	g.cmd(C_SRCH, sx=sx, sy=y, clr=clr, arg=arg, autofill=False)
	g.end()


def suite_srch(g, m, level):
	W, sh, cm, _ = GEOM[m.geom]
	bg, tc = (5 & cm) or 1, (9 & cm) or 2
	if cm == 3:
		bg, tc = 1, 2
	if cm == 0xFF:
		bg, tc = 0x25, 0x9A
	cases = [
		('SRCH EQ=0 発見 DIX=0', 300, [(37, tc)], 5, tc, 0),
		('SRCH EQ=0 未発見 DIX=0', 302, [], 5, tc, 0),
		('SRCH EQ=0 発見 DIX=1', 304, [(37, tc)], W - 5, tc, DIX),
		('SRCH EQ=0 未発見 DIX=1', 306, [], W - 5, tc, DIX),
		('SRCH EQ=1 発見', 308, [(W - 20, tc)], 9, bg, EQ),
		('SRCH EQ=1 未発見', 310, [(3, tc)], 9, bg, EQ),
		('SRCH 開始点で発見', 312, [(77, tc)], 77, tc, 0),
		('SRCH 右端 X=%d で発見' % (W - 1), 314, [(W - 1, tc)], 100, tc, 0),
		('SRCH 色の上位ビットは無視', 316, [(50, tc)], 1, tc | (0xF0 & ~cm & 0xFF), 0),
		('SRCH EQ=1 DIX=1 未発見', 318, [(W - 2, tc)], W - 3, bg, EQ | DIX),
	]
	if level < 2:
		cases = cases[:4] + cases[4:5]
	elif level < 3:
		cases = cases[:8]
	for desc, y, tg, sx, clr, arg in cases:
		srch_case(g, m, desc, y, bg, tg, sx, clr, arg)


def suite_ignored(g, m):
	g.sub('コマンド無効')
	g.begin('CMD=0 では HMMV が実行されない', m)
	g.fillp(0x1000, 0x400)
	g.cmd(C_HMMV, dx=0, dy=16, nx=64, ny=4, clr=0x77)
	g.read(0x1000, 0x400)
	g.end()


def suite_cpu(g):
	g.sub('CPU VRAM 読み書き (R#14)')
	sc5 = mode('SCREEN5')
	for bank in (0, 1, 3, 4, 6, 7):
		base = bank * 0x4000
		g.begin('R#14=%d: 0x%05X から 512 バイト書いて読む' % (bank, base + 0x1230), sc5)
		g.fillp(base + 0x1200, 0x280)
		g.cpuw(base + 0x1230, 0x200, 0x40 + bank)
		g.cpur(base + 0x1230, 0x200)
		g.read(base + 0x1200, 0x280)
		g.end()
	for bank in (0, 3, 7):
		base = bank * 0x4000
		g.begin('R#14=%d: 16KB 境界をまたぐ連続書き込み (SCREEN5, 17 ビット)' % bank, sc5)
		g.fillp(base + 0x3F00, 0x100)
		g.fillp((base + 0x4000) & 0x1FFFF, 0x100)
		g.cpuw(base + 0x3F80, 0x100, 0x11 * bank + 3)
		g.cpur(base + 0x3F80, 0x100)
		g.read(base + 0x3F00, 0x100)
		g.read((base + 0x4000) & 0x1FFFF, 0x100)
		g.end()
	sc1 = mode('SCREEN1')
	for bank in (2, 5):
		base = bank * 0x4000
		g.begin('R#14=%d: SCREEN1 では 16KB 内で折り返す' % bank, sc1)
		g.fillp(base, 0x100)
		g.fillp(base + 0x3F00, 0x100)
		g.fillp(base + 0x4000, 0x100)
		g.cpuw(base + 0x3F80, 0x100, 0x5A + bank)
		g.cpur(base + 0x3F80, 0x100)
		g.read(base, 0x100)
		g.read(base + 0x3F00, 0x100)
		g.read(base + 0x4000, 0x100)
		g.end()
	for name in ('SCREEN7', 'SCREEN8'):
		m = mode(name)
		g.begin('%s で書いて SCREEN5 で読む (インターリーブ)' % name, m)
		g.fillp(0x0000, 0x400)
		g.fillp(0x10000, 0x400)
		g.cpuw(0x0100, 0x300, 0x77)
		g.set_mode(sc5)
		g.read(0x0000, 0x200)
		g.read(0x10000, 0x200)
		g.end()
		g.begin('%s: R#14=7 の読み書き' % name, m)
		g.fillp(0x1C000, 0x400)
		g.cpuw(0x1C123, 0x200, 0x99)
		g.cpur(0x1C100, 0x300)
		g.read(0x1C000, 0x400)
		g.end()


def build():
	g = Gen()
	g.section('CPU による VRAM 読み書き')
	suite_cpu(g)

	full = [('SCREEN5', 3), ('SCREEN8', 3), ('SCREEN6', 1), ('SCREEN7', 1), ('SCREEN10', 0), ('SCREEN12', 0)]
	for name, lv in full:
		m = mode(name)
		g.section('%s のコマンド' % name)
		if lv:
			suite_commands(g, m, lv)
		else:
			suite_mini(g, m)

	g.section('SCREEN0-4 で R#25 CMD=1 (SCREEN8 相当)')
	for name in ('SCREEN0(W40)', 'SCREEN0(W80)', 'SCREEN1', 'SCREEN2', 'SCREEN3', 'SCREEN4'):
		suite_mini(g, mode(name, cmd=True))
	for name in ('SCREEN1', 'SCREEN4'):
		suite_ignored(g, mode(name))

	for name in ('SCREEN0(W40)', 'SCREEN0(W80)', 'SCREEN1', 'SCREEN2', 'SCREEN3', 'SCREEN4', 'SCREEN5',
			'SCREEN6', 'SCREEN7', 'SCREEN8', 'SCREEN10', 'SCREEN11', 'SCREEN12'):
		g.section('%s で FG4=1 (SCREEN5 相当, V9968 のみ)' % name, v9968_only=True)
		bitmap = BASE[name][0] in ('G4', 'G5', 'G6', 'G7')
		suite_mini(g, mode(name, cmd=not bitmap, fg4=True))
		if name in ('SCREEN1', 'SCREEN4'):
			suite_ignored(g, mode(name, fg4=True))
	g.finish()
	return g


def write_outputs(g):
	code = bytes(g.code)
	with open(os.path.join(HERE, 'VDPCHK.INC'), 'w', newline='\r\n') as f:
		f.write('; generated by gen_vdpchk.py -- do not edit\n')
		f.write('TOTAL_TESTS\t:= %d\n' % g.num)
		f.write('pat_table::\n')
		for i in range(0, 256, 16):
			f.write('\t\tdb\t\t' + ', '.join('0x%02X' % v for v in PAT[i:i + 16]) + '\n')
		f.write('crc_table_hi::\n')
		for i in range(0, 256, 16):
			f.write('\t\tdb\t\t' + ', '.join('0x%02X' % (v >> 8) for v in CRC_T[i:i + 16]) + '\n')
		f.write('crc_table_lo::\n')
		for i in range(0, 256, 16):
			f.write('\t\tdb\t\t' + ', '.join('0x%02X' % (v & 0xFF) for v in CRC_T[i:i + 16]) + '\n')
		f.write('script::\n')
		for i in range(0, len(code), 16):
			f.write('\t\tdb\t\t' + ', '.join('0x%02X' % v for v in code[i:i + 16]) + '\n')
		f.write('script_end::\n')
	with open(os.path.join(HERE, 'vdpchk.hex'), 'w') as f:
		for v in code:
			f.write('%02X\n' % v)
	with open(os.path.join(HERE, 'pat.hex'), 'w') as f:
		for v in PAT:
			f.write('%02X\n' % v)
	with open(os.path.join(HERE, 'vdpchk_expect.txt'), 'w') as f:
		for n, log in g.expect:
			f.write('%d %04X %d %s\n' % (n, crc16(log), len(log),
				''.join('%02X' % v for v in log[:4096])))

	with open(os.path.join(HERE, 'test_item.md'), 'w', encoding='utf-8', newline='\n') as f:
		f.write('# VDPCHK テスト項目一覧\n\n')
		f.write('このファイルは `gen_vdpchk.py` が生成します。直接編集しないでください。\n\n')
		f.write('- 全 %d 項目。VDPCHK.COM は失敗した項目の番号を最後に表示します。\n' % g.num)
		f.write('- 期待値は openMSX の VDPCmdEngine (実機で確認された動作) とデータブックに準拠した参照モデルで生成しています。\n')
		f.write('- 各項目は試験範囲を既知のパターンで埋めてから実行し、CPU で VRAM を読み戻して CRC で比較します。'
			'範囲はコマンドが触れるライン全体と、その上下 1 ラインです。\n')
		f.write('- 「V9968 のみ」の節は V9968 を検出できない場合 (V9958 実機など) はスキップし、全数に含めません。\n')
		f.write('- 番号の後ろの `T` はタイムアウト (CE または TR が落ちなかった) を表します。\n')
		for it in g.items:
			if it[0] == 'section':
				f.write('\n## %s\n' % it[1])
			elif it[0] == 'group':
				f.write('\n### %s\n\n| No. | モード | 内容 |\n|---:|---|---|\n' % it[1])
			else:
				f.write('| %d | %s | %s |\n' % (it[1], it[2], it[4]))
	return code


def main():
	g = build()
	code = write_outputs(g)
	ext = sum(1 for it in g.items if it[0] == 'test')
	print('tests=%d script=%d bytes' % (ext, len(code)))


if __name__ == '__main__':
	main()
