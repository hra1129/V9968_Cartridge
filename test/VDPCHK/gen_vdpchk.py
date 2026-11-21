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
#	The last section (V9968 only) checks the 4MB VRAM banks R#28 (CPU),
#	R#29 (sprite, by the S#0 collision flag) and R#30 (command source /
#	destination).  Every bank gets its own fill pattern (bank_seed) and the
#	banks that differ from the target in one bank bit are read back too.
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
	OP_STAT, OP_FILLP, OP_FILLC, OP_READ, OP_CPUW, OP_CPUR, OP_SECTION, \
	OP_FRAME, OP_CPUWC, OP_CPURC, OP_BFILLP, OP_BREAD = range(21)

VRAM_SIZE = 0x400000		# V9968: 16 banks x 256 KB (R#28/R#29/R#30 give A21..A18)

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
C_LFMM = 0x10			# V9968: font (R#32-R#34, source bank) -> rectangle, FG = R#44, BG = R#12
CNAME = {0x10: 'LFMM', 0x40: 'POINT', 0x50: 'PSET', 0x60: 'SRCH', 0x70: 'LINE', 0x80: 'LMMV', 0x90: 'LMMM',
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
		self.rows = set()			# (bank, address) touched in the dry run

	# --- VRAM access through the logical -> physical mapping of the display mode.
	#	Source reads use the R#30 source bank, destination accesses (including the
	#	read of a logical operation) the R#30 destination bank.
	def rd(self, a, side='s'):
		a &= self.g.amask
		bk = self.g.src_bank if side == 's' else self.g.dst_bank
		if self.dry:
			self.rows.add((bk, a))
			p = self.g.phys(a, bk)
			return self.g.vram[p] if self.g.known[p] else 0
		return self.g.rd(a, bk)

	def wr(self, a, v):
		a &= self.g.amask
		bk = self.g.dst_bank
		if self.dry:
			self.rows.add((bk, a))
			return
		self.g.wr(a, v, bk)

	def addr(self, x, y):
		k = self.geom
		big = self.g.v256
		if k == 'G4':
			return ((y & (2047 if big else 1023)) << 7) | ((x & 255) >> 1)
		if k == 'G5':
			return ((y & (2047 if big else 1023)) << 7) | ((x & 511) >> 2)
		if k == 'G6':
			return ((y & (1023 if big else 511)) << 8) | ((x & 511) >> 1)
		return ((y & (1023 if big else 511)) << 8) | (x & 255)

	def point(self, x, y):
		b = self.rd(self.addr(x, y))
		if self.geom in ('G4', 'G6'):
			return (b >> (((~x) & 1) << 2)) & 15
		if self.geom == 'G5':
			return (b >> (((~x) & 3) << 1)) & 3
		return b

	def pset(self, x, y, color, lop):
		a = self.addr(x, y)
		src = self.rd(a, 'd')
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

	def ny0(self):
		return 2048 if self.g.v256 else 1024		# NY=0 (2048 lines in the 256 KB mode)

	def clipy1(self, dy, ny, arg):
		ny = ny if ny else self.ny0()
		return min(ny, dy + 1) if arg & DIY else ny

	def clipy2(self, sy, dy, ny, arg):
		ny = ny if ny else self.ny0()
		return min(ny, min(sy, dy) + 1) if arg & DIY else ny

	# --- command execution.  Returns a list of status/transfer bytes to log.
	def run(self, geom, r, data):
		self.geom = geom
		self.ppl, self.sh, self.cmask, _ = GEOM[geom]
		ymask = 0x7FF if self.g.v256 else 0x3FF
		sx, sy = r['sx'] & 0x1FF, r['sy'] & ymask
		dx, dy = r['dx'] & 0x1FF, r['dy'] & ymask
		nx, ny = r['nx'] & 0x3FF, r['ny'] & ymask
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
			lmask = 2047 if self.g.v256 else 1023
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
					asx = (asx - ny) & lmask
				else:
					dy += ty
					if ty < 0 and dy < 0:
						break
					if asx < ny:
						asx += nx
						adx += tx
					asx = (asx - ny) & lmask
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
		elif c == C_LFMM:
			# characters of 8 dots x NY rows, one byte per row (MSB = left), stored one
			# after another at the CPU-view font address.  Only fully visible text is modelled.
			fa = (r['sx'] | (r['sy'] << 16)) & 0x3FFFF
			bg = r['bg'] & self.cmask
			assert not arg & (DIX | DIY) and 0 < nx and 0 < ny
			assert dx + 8 * nx <= self.ppl and dy + ny <= (self.g.amask + 1) // GEOM[geom][3]
			for ch in range(nx):
				for row in range(ny):
					v = self.rd(fa)
					fa += 1
					for b in range(8):
						self.pset(dx + 8 * ch + b, dy + row, col if (v >> (7 - b)) & 1 else bg, lop)
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
		self.vram = bytearray(VRAM_SIZE)
		self.known = bytearray(VRAM_SIZE)
		self.mode = None
		self.cur_key = None
		self.ext = False
		self.bd = False
		self.col = 0
		self.log = None
		self.sec = None
		self.group = ''
		self.seed = 0x31
		# V9968 extension state as left by VDPCHK.ASM detect_vdp: V58=1, locked
		self.v58 = 1
		self.lock = 1
		self.cpu_bank = self.bg_bank = self.spr_bank = self.src_bank = self.dst_bank = 0
		self.rpref = None			# (address, bank) of the byte in the CPU read-ahead buffer
		self.wptr = None			# next CPU write address

	@property
	def v256(self):
		return not self.v58

	@property
	def amask(self):
		return 0x3FFFF if self.v256 else 0x1FFFF

	# --- low level emit
	def b(self, *v):
		for x in v:
			self.code.append(x & 0xFF)

	def w(self, v):
		self.b(v & 0xFF, (v >> 8) & 0xFF)

	def a24(self, v):
		self.b(v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF)

	# --- VRAM model.  bank None = the CPU bank (R#28).
	def phys(self, a, bank=None):
		bank = self.cpu_bank if bank is None else bank
		a &= self.amask
		if self.mode is not None and self.mode.ilv:
			a = (a & 0x20000) | ((a & 1) << 16) | ((a & 0x1FFFF) >> 1)
		return (bank << 18) | a

	def rd(self, a, bank=None):
		p = self.phys(a, bank)
		if not self.known[p]:
			raise UnknownRead('test %d reads unknown VRAM %X:%05X' % (self.num, p >> 18, a))
		return self.vram[p]

	def wr(self, a, v, bank=None):
		p = self.phys(a, bank)
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
			self.p4(0x80)
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
		# model of the V9968 extension registers (vdp_cpu_interface.v)
		if self.lock:
			return
		if r == 21:
			self.v58 = v & 1
			if self.v58:
				self.cpu_bank = self.bg_bank = self.spr_bank = self.src_bank = self.dst_bank = 0
		elif self.v58:
			return
		elif r == 28:
			self.cpu_bank = v & 15
		elif r == 29:
			self.bg_bank, self.spr_bank = v & 15, (v >> 4) & 15
		elif r == 30:
			self.src_bank, self.dst_bank = v & 15, (v >> 4) & 15

	def p4(self, v):
		self.b(OP_P4, v)
		self.lock = (v >> 7) & 1

	def set_cpu_bank(self, bk):
		if self.cpu_bank != bk:
			self.reg(28, bk)
		assert self.cpu_bank == bk

	def set_cmd_banks(self, src, dst):
		if (self.src_bank, self.dst_bank) != (src, dst):
			self.reg(30, (dst << 4) | src)
		assert (self.src_bank, self.dst_bank) == (src, dst)

	def bank_seed(self, bk):
		# a different pattern in every bank: a read from a wrong bank changes the CRC
		return (self.seed + bk * 0x3B) & 0xFF

	def set_mode(self, m):
		self.mode = m
		if self.cur_key == m.key():
			return
		if self.ext and self.cur_key is None:
			self.p4(0x00)			# unlock R#20/R#21
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
		self.known = bytearray(VRAM_SIZE)
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

	# --- memory ops (CPU bank)
	def fillp(self, a, n, seed=None):
		seed = self.seed if seed is None else seed
		assert 0 < n <= 0x10000 and a + n <= self.amask + 1
		self.b(OP_FILLP)
		self.a24(a)
		self.w(n & 0xFFFF)
		self.b(seed)
		for i in range(n):
			self.wr(a + i, pat_byte(a + i, seed))
		self.rpref = self.wptr = None

	def fillc(self, a, n, v):
		assert 0 < n <= 0x10000 and a + n <= self.amask + 1
		self.b(OP_FILLC)
		self.a24(a)
		self.w(n & 0xFFFF)
		self.b(v)
		for i in range(n):
			self.wr(a + i, v)
		self.rpref = self.wptr = None

	def read(self, a, n):
		assert 0 < n <= 0x10000 and a + n <= self.amask + 1
		self.b(OP_READ)
		self.a24(a)
		self.w(n & 0xFFFF)
		for i in range(n):
			self.log.append(self.rd(a + i))
		self.rpref = self.wptr = None

	def fill_regions(self, regs, seed=None):
		for a, n in regs:
			while n:
				k = min(n, 0x10000)
				self.fillp(a, k, seed)
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
			return (a & self.amask & ~0x3FFF) | ((a + 1) & 0x3FFF)
		return (a + 1) & self.amask

	def cpuw(self, a, n, seed):
		assert 0 < n <= 0x4000
		self.b(OP_CPUW)
		self.a24(a)
		self.w(n)
		self.b(seed)
		self.wptr = a
		self._cpuw(n, seed)

	def cpuwc(self, n, seed):
		"""continue writing at the current VRAM address (no address setup)"""
		assert 0 < n <= 0x4000 and self.wptr is not None
		self.b(OP_CPUWC)
		self.w(n)
		self.b(seed)
		self._cpuw(n, seed)

	def _cpuw(self, n, seed):
		a = self.wptr
		for k in range(n):
			self.wr(a, PAT[(seed + k) & 0xFF])
			a = self.cpu_next(a)
		self.wptr = a
		self.rpref = None

	def cpur(self, a, n):
		assert 0 < n <= 0x4000
		self.b(OP_CPUR)
		self.a24(a)
		self.w(n)
		for _ in range(n):
			self.log.append(self.rd(a))
			a = self.cpu_next(a)
		# the address setup and every read fetch the next byte with the bank of that moment
		self.rpref = (a, self.cpu_bank)
		self.wptr = None

	def cpurc(self, n):
		"""continue reading: the first byte comes from the read-ahead buffer"""
		assert 0 < n <= 0x4000 and self.rpref is not None
		self.b(OP_CPURC)
		self.w(n)
		a, bk = self.rpref
		for _ in range(n):
			self.log.append(self.rd(a, bk))
			a = self.cpu_next(a)
			bk = self.cpu_bank
		self.rpref = (a, self.cpu_bank)

	def stat(self, n, mask, value=None):
		self.b(OP_STAT, n, mask)
		if mask:
			self.log.append(value & mask)

	def frame(self):
		"""clear S#0 in the vertical blanking and wait until one whole frame is displayed"""
		self.b(OP_FRAME)

	# --- command
	def rowbytes(self):
		return GEOM[self.mode.geom][3] if self.mode.geom else 256

	def regions_of(self, addrs, margin=1):
		rb = self.rowbytes()
		nrows = (self.amask + 1) // rb
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

	def bank_plan(self, rows, guard=()):
		"""rows: (bank, address) touched by a command -> [(bank, regions)].
		Guard banks get the union of all regions: they must not change."""
		by = {}
		for bk, a in rows:
			by.setdefault(bk, set()).add(a)
		allr = set(a for _, a in rows)
		for bk in guard:
			by.setdefault(bk, set()).update(allr)
		return [(bk, self.regions_of(by[bk])) for bk in sorted(by)]

	# --- the same regions in several banks (R#28 = every bank of the mask, then restored)
	def _bank_op(self, op, a, n, bks, restore):
		assert 0 < n <= 0x10000 and a + n <= self.amask + 1
		assert self.v256 and not self.lock and 0 <= restore < 16
		mask = 0
		for bk in bks:
			mask |= 1 << bk
		self.b(op)
		self.a24(a)
		self.w(n & 0xFFFF)
		self.w(mask)
		return mask

	def bfillp(self, a, n, bks, seed=None, restore=None):
		"""fill in every bank of bks; the seed of bank k is seed + k * 3Bh (bank_seed)"""
		seed = self.seed if seed is None else seed
		restore = self.cpu_bank if restore is None else restore
		mask = self._bank_op(OP_BFILLP, a, n, bks, restore)
		self.b(seed, restore)
		for bk in range(16):
			if mask >> bk & 1:
				s = (seed + bk * 0x3B) & 0xFF
				for i in range(n):
					self.wr(a + i, pat_byte(a + i, s), bk)
		self.cpu_bank = restore
		self.rpref = self.wptr = None

	def bread(self, a, n, bks, restore=None):
		"""read back every bank of bks (ascending bank order)"""
		restore = self.cpu_bank if restore is None else restore
		mask = self._bank_op(OP_BREAD, a, n, bks, restore)
		self.b(restore)
		for bk in range(16):
			if mask >> bk & 1:
				for i in range(n):
					self.log.append(self.rd(a + i, bk))
		self.cpu_bank = restore
		self.rpref = self.wptr = None

	def bank_regions(self, fn, regs, bks):
		for a, n in regs:
			while n:
				k = min(n, 0x10000)
				fn(a, k, bks)
				a += k
				n -= k

	def plan_union(self, plan):
		rb = self.rowbytes()
		rows = set()
		for _, regs in plan:
			for a, n in regs:
				rows.update(range(a, a + n, rb))
		return self.regions_of(rows, margin=0), [bk for bk, _ in plan]

	def fill_plan(self, plan):
		if len(plan) == 1 and plan[0][0] == self.cpu_bank == 0:
			self.fill_regions(plan[0][1], self.bank_seed(0))
			return
		regs, bks = self.plan_union(plan)
		self.bank_regions(self.bfillp, regs, bks)

	def read_plan(self, plan):
		if len(plan) == 1 and plan[0][0] == self.cpu_bank == 0:
			self.read_regions(plan[0][1])
			return
		regs, bks = self.plan_union(plan)
		self.bank_regions(self.bread, regs, bks)

	def cmd(self, c, sx=0, sy=0, dx=0, dy=0, nx=0, ny=0, clr=0, arg=0, autofill=True, check=True,
			guard=(), before=None, between=None, bg=0):
		"""guard: banks that get the same regions and must not change.
		before: called after the fill and before the command (CPU accesses).
		between: called while the command is running (CPU accesses to other banks)."""
		m = self.mode
		seed = self.seed
		cc = c & 0xF0
		if cc in (C_LMMC, C_HMMC):
			clr = PAT[seed]
		r = dict(sx=sx, sy=sy, dx=dx, dy=dy, nx=nx, ny=ny, clr=clr, arg=arg, cmd=c, bg=bg)

		def data(k):
			return PAT[(seed + k) & 0xFF]
		plan = []
		if m.geom and autofill:
			dry = Engine(self, dry=True)
			dry.run(m.geom, r, data)
			plan = self.bank_plan(dry.rows, guard)
			self.fill_plan(plan)
		if before:
			before()
		if cc == C_SRCH:
			self.stat(9, 0)					# clears BD
		if cc == C_LMCM:
			self.stat(7, 0)					# clears a stale TR
		if cc == C_LFMM:
			self.reg(12, bg)				# LFMM background colour
		arg_out = arg | (0x80 if m.fg4 else 0)
		self.b(OP_CMD, sx, sx >> 8, sy, sy >> 8, dx, dx >> 8, dy, dy >> 8,
			nx, nx >> 8, ny, ny >> 8, clr, arg_out, c)
		res = None
		if m.geom:
			res = Engine(self).run(m.geom, r, data)
		if between:
			assert cc not in (C_LMMC, C_HMMC, C_LMCM)
			between()
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
		if check and plan:
			self.read_plan(plan)
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


# ---------------------------------------------------------------------------
#	VRAM banks (V9968 4MB): R#28 CPU, R#29 BG/sprite, R#30 command src/dst
# ---------------------------------------------------------------------------
def nbanks(bk, *skip):
	"""banks that differ from bk in one address bit (A18..A21): catch stuck / swapped bank lines"""
	return tuple(x for x in (bk ^ 1, bk ^ 2, bk ^ 4, bk ^ 8) if x not in skip)


def banks(g, cpu=0, src=0, dst=0):
	g.set_cpu_bank(cpu)
	g.set_cmd_banks(src, dst)


def fill_banks(g, bks, regs):
	g.bank_regions(g.bfillp, regs, bks)


def read_banks(g, bks, regs):
	g.bank_regions(g.bread, regs, bks)


def BT(g, m, desc, src, dst, c, guard=None, cpu=0, **kw):
	g.begin(desc, m)
	banks(g, cpu, src, dst)
	if guard is None:
		guard = nbanks(dst, src)
	g.cmd(c, guard=guard, **kw)
	g.end()


def suite_bank_regs(g):
	sc5 = mode('SCREEN5')
	g.sub('バンクレジスタの書き込み条件')
	regs = [(0x12300, 0x100)]
	g.begin('R#28 の上位 4 ビットは無視 (F5h = バンク 5)', sc5)
	banks(g)
	fill_banks(g, (0, 5, 15), regs)
	g.reg(28, 0xF5)
	assert g.cpu_bank == 5
	g.cpuw(0x12340, 0x80, 0x21)
	read_banks(g, (0, 5, 15), regs)
	g.end()

	g.begin('P#4 ロック中は R#28 の書き込みを無視', sc5)
	banks(g, cpu=2)
	fill_banks(g, (2, 6), regs)
	g.p4(0x80)
	g.reg(28, 6)
	g.cpuw(0x12340, 0x80, 0x22)
	g.p4(0x00)
	read_banks(g, (2, 6), regs)
	g.end()

	g.begin('P#4 ロック中は R#30 の書き込みを無視 (HMMV は DST=1 のまま)', sc5)
	banks(g, src=1, dst=1)
	g.cmd(C_HMMV, dx=16, dy=600, nx=64, ny=3, clr=0x6D, guard=(7, 0),
		before=lambda: (g.p4(0x80), g.reg(30, 0x77)), between=lambda: g.p4(0x00))
	g.end()

	g.begin('R#29 は CPU/コマンドのバンクを変えない', sc5)
	banks(g, cpu=4, src=4, dst=4)
	g.reg(29, 0xBE)
	g.cmd(C_HMMV, dx=32, dy=700, nx=96, ny=3, clr=0x93, guard=(0x0B, 0x0E, 0),
		before=lambda: g.cpuw(700 * 128 + 0x60, 0x40, 0x23))
	g.reg(29, 0x00)
	g.end()

	g.begin('R#21 V58=1 で全バンクが 0 に戻り、V58=1 の間は R#28/R#30 を無視', sc5)
	regs = [(0x01000, 0x200)]
	bks = (0, 3, 9, 12)
	fill_banks(g, bks, regs)
	banks(g, cpu=9, src=3, dst=12)
	g.reg(29, 0x5A)
	g.reg(21, 0x01)
	assert (g.cpu_bank, g.src_bank, g.dst_bank) == (0, 0, 0)
	g.reg(28, 9)
	g.reg(30, 0xCC)
	g.cpuw(0x01000, 0x80, 0x24)
	g.cmd(C_HMMV, dx=0, dy=0x1080 // 128, nx=256, ny=2, clr=0x5C, autofill=False, check=False)
	g.reg(21, 0x00)
	read_banks(g, bks, regs)
	g.end()

	g.begin('R#30 は下位 4 ビットが SRC、上位 4 ビットが DST', sc5)
	g.reg(30, 0xD2)
	assert (g.src_bank, g.dst_bank) == (2, 13)
	g.cmd(C_HMMM, sx=0, sy=900, dx=0, dy=900, nx=256, ny=2, guard=(0x0D ^ 1, 2 ^ 1, 0))
	g.end()


def suite_bank_cpu(g):
	g.sub('CPU (R#28) による全バンクの読み書き')
	edges = [(0x00000, 0x100), (0x1FF80, 0x100), (0x3FF00, 0x100)]
	for name in ('SCREEN5', 'SCREEN8'):
		m = mode(name)
		g.begin('全 16 バンクに異なるパターンを書いて読み戻す (先頭/128KB 境界/末尾)', m)
		banks(g)
		fill_banks(g, range(16), edges)
		read_banks(g, range(16), edges)
		g.end()
	sc5 = mode('SCREEN5')
	for i, k in enumerate((1, 2, 4, 8, 14, 13, 11, 7)):
		a = (0x3FF00 - i * 0x8421) & 0x3FF00
		regs = [(a, 0x100)]
		g.begin('バンク %d だけに書き、他の 15 バンクの 0x%05X が壊れない' % (k, a), sc5)
		banks(g)
		fill_banks(g, range(16), regs)
		g.set_cpu_bank(k)
		g.cpuw(a + 0x40, 0x80, 0x30 + k)
		read_banks(g, range(16), regs)
		g.end()
	for bk in (0, 7, 15):
		nx = (bk + 1) & 15
		regs = [(0x00000, 0x100), (0x3FF00, 0x100)]
		g.begin('バンク %d: 0x3FFFF から同じバンクの 0x00000 へ折り返す (バンク %d は不変)' % (bk, nx), sc5)
		banks(g, cpu=bk)
		fill_banks(g, (bk, nx), regs)
		g.cpuw(0x3FFC0, 0x80, 0x40 + bk)
		g.cpur(0x3FFC0, 0x80)
		read_banks(g, (bk, nx), regs)
		g.end()
	for name, bk in (('SCREEN5', 3), ('SCREEN8', 12)):
		m = mode(name)
		regs = [(0x1FF00, 0x200)]
		g.begin('バンク %d: 0x1FFFF から 0x20000 への連続書き込み' % bk, m)
		banks(g, cpu=bk)
		fill_banks(g, (bk, bk ^ 1, bk ^ 8), regs)
		g.cpuw(0x1FF80, 0x100, 0x50 + bk)
		g.cpur(0x1FF80, 0x100)
		read_banks(g, (bk, bk ^ 1, bk ^ 8), regs)
		g.end()
	sc1 = mode('SCREEN1')
	regs = [(0x38000, 0x100), (0x3BF00, 0x100), (0x3C000, 0x100)]
	g.begin('バンク 10: SCREEN1 では 16KB 内で折り返す (A17-A14 とバンクは保持)', sc1)
	banks(g, cpu=10)
	fill_banks(g, (10, 11), regs)
	g.cpuw(0x3BF80, 0x100, 0x5A)
	g.cpur(0x3BF80, 0x100)
	read_banks(g, (10, 11), regs)
	g.end()

	g.sub('CPU アクセスの途中で R#28 を変更')
	for name, a in (('SCREEN5', 0x2A0F8), ('SCREEN8', 0x1C3F8)):
		m = mode(name)
		regs = [(a & ~0xFF, 0x200)]
		g.begin('読み出し中に R#28 を 3->12: 先読み済みの 1 バイトは旧バンク', m)
		banks(g, cpu=3)
		fill_banks(g, (3, 12), regs)
		g.cpur(a, 0x10)
		g.set_cpu_bank(12)
		g.cpurc(0x20)
		g.end()
		g.begin('書き込み中に R#28 を 5->9: 以降の書き込みは新バンク', m)
		banks(g, cpu=5)
		fill_banks(g, (5, 9), regs)
		g.cpuw(a - 0x20, 0x40, 0x61)
		g.set_cpu_bank(9)
		g.cpuwc(0x40, 0x62)
		read_banks(g, (5, 9), regs)
		g.end()


def srch_bank_case(g, m, desc, y, src, others, tc, eq):
	W, sh, cm, rb = GEOM[m.geom]
	e = Engine(g)
	e.geom, e.ppl, e.sh, e.cmask = m.geom, W, sh, cm
	g.begin(desc, m)
	banks(g, 0, src, others[0])
	bg = 5
	rep = bg * 0x11 if sh == 1 else 0x25
	if sh == 0:
		bg = 0x25
	a0 = e.addr(0, y)
	cpu = g.cpu_bank
	for i, bk in enumerate((src,) + others):
		g.set_cpu_bank(bk)
		g.fillc(a0, rb, rep)
		put_pixel_byte(g, m, y, 40 + 50 * i, bg, tc)
	g.set_cpu_bank(cpu)
	g.cmd(C_SRCH, sx=3, sy=y, clr=bg if eq else tc, arg=EQ if eq else 0, autofill=False)
	g.end()


def suite_bank_cmd(g):
	sc5, sc8 = mode('SCREEN5'), mode('SCREEN8')
	g.sub('VDP コマンド (R#30) SCREEN5: 256KB = Y 0-2047')
	BT(g, sc5, 'HMMV DST=1', 0, 1, C_HMMV, dx=10, dy=100, nx=100, ny=3, clr=0xA7)
	BT(g, sc5, 'HMMV DST=8', 0, 8, C_HMMV, dx=10, dy=100, nx=100, ny=3, clr=0xA7)
	BT(g, sc5, 'HMMV DST=15', 0, 15, C_HMMV, dx=10, dy=100, nx=100, ny=3, clr=0xA7)
	BT(g, sc5, 'HMMV DST=5 Y=1022-1025 (128KB 境界)', 0, 5, C_HMMV, dx=0, dy=1022, nx=256, ny=4, clr=0x3C)
	BT(g, sc5, 'HMMV DST=10 Y=2046-1 (バンク内で折り返す)', 0, 10, C_HMMV, dx=0, dy=2046, nx=256, ny=4, clr=0xC5)
	BT(g, sc5, 'HMMV DST=6 DIY=1 Y=1025-1022', 0, 6, C_HMMV, dx=64, dy=1025, nx=64, ny=4, clr=0x5A, arg=DIY)
	BT(g, sc5, 'LMMV XOR DST=7 Y=1500', 7, 7, C_LMMV | 3, dx=33, dy=1500, nx=70, ny=3, clr=0x0B, guard=nbanks(7))
	BT(g, sc5, 'HMMM SRC=3 DST=12 (同じ座標)', 3, 12, C_HMMM, sx=0, sy=700, dx=0, dy=700, nx=256, ny=3)
	BT(g, sc5, 'HMMM SRC=DST=5 重なり', 5, 5, C_HMMM, sx=10, sy=300, dx=20, dy=302, nx=100, ny=6, guard=nbanks(5))
	BT(g, sc5, 'HMMM SRC=9 Y=1022-1025 -> DST=6 Y=2046-1', 9, 6, C_HMMM, sx=0, sy=1022, dx=0, dy=2046, nx=256, ny=4)
	BT(g, sc5, 'HMMM DIY=1 SRC=1 Y=2047-2046 -> DST=2 Y=1-0', 1, 2, C_HMMM, sx=8, sy=2047, dx=8, dy=1, nx=200, ny=2, arg=DIY)
	BT(g, sc5, 'LMMM XOR SRC=14 DST=1', 14, 1, C_LMMM | 3, sx=5, sy=1200, dx=9, dy=1800, nx=90, ny=3)
	BT(g, sc5, 'LMMM TIMP SRC=0 DST=15', 0, 15, C_LMMM | 8, sx=7, sy=1300, dx=3, dy=1301, nx=120, ny=3)
	BT(g, sc5, 'YMMM SRC=11 DST=4', 11, 4, C_YMMM, sy=1800, dx=64, dy=1800, ny=3, arg=DIX)
	BT(g, sc5, 'LMCM SRC=13 (DST=2)', 13, 2, C_LMCM, sx=10, sy=1900, nx=8, ny=2, guard=(2, 12, 0))
	BT(g, sc5, 'POINT SRC=6 (DST=9)', 6, 9, C_POINT, sx=77, sy=1234, guard=(9, 7, 14, 0))
	BT(g, sc5, 'PSET OR DST=3 (SRC=12 は使わない)', 12, 3, C_PSET | 2, dx=101, dy=1777, clr=0x0A)
	BT(g, sc5, 'LINE DST=14 (SRC=1)', 1, 14, C_LINE, dx=20, dy=1020, nx=80, ny=9, clr=0x0D)
	BT(g, sc5, 'LMMC TIMP DST=5 (SRC=10)', 10, 5, C_LMMC | 8, dx=50, dy=2040, nx=6, ny=3)
	BT(g, sc5, 'HMMC DST=12 Y=2047-0', 0, 12, C_HMMC, dx=17, dy=2047, nx=16, ny=2)
	srch_bank_case(g, sc5, 'SRCH SRC=9: バンクごとに異なる X に目標色', 1600, 9, (0, 8, 11, 1), 9, False)
	srch_bank_case(g, sc5, 'SRCH EQ=1 SRC=4', 1700, 4, (0, 5, 12), 9, True)

	g.begin('HMMV NX=0 NY=0 で DST=6 の 256KB 全体を塗る (バンク 5 末尾/7 先頭/14 は不変)', sc5)
	banks(g, src=0, dst=6)
	g.set_cpu_bank(5)
	g.fillp(0x3FF00, 0x100, g.bank_seed(5))
	g.set_cpu_bank(7)
	g.fillp(0x00000, 0x100, g.bank_seed(7))
	g.set_cpu_bank(14)
	g.fillp(0x20000 - 0x80, 0x100, g.bank_seed(14))
	g.set_cpu_bank(0)
	g.cmd(C_HMMV, dx=0, dy=0, nx=0, ny=0, clr=0x96, autofill=False, check=False)
	read_banks(g, (6,), [(0, 0x40000)])
	read_banks(g, (5,), [(0x3FF00, 0x100)])
	read_banks(g, (7,), [(0x00000, 0x100)])
	read_banks(g, (14,), [(0x20000 - 0x80, 0x100)])
	g.end()

	g.sub('VDP コマンド (R#30) SCREEN8: 256KB = Y 0-1023 (インターリーブ)')
	BT(g, sc8, 'HMMV DST=1', 0, 1, C_HMMV, dx=10, dy=100, nx=100, ny=3, clr=0xA7)
	BT(g, sc8, 'HMMV DST=8', 0, 8, C_HMMV, dx=10, dy=100, nx=100, ny=3, clr=0xA7)
	BT(g, sc8, 'HMMV DST=15', 0, 15, C_HMMV, dx=10, dy=100, nx=100, ny=3, clr=0xA7)
	BT(g, sc8, 'HMMV DST=5 Y=510-513 (128KB 境界)', 0, 5, C_HMMV, dx=0, dy=510, nx=256, ny=4, clr=0x3C)
	BT(g, sc8, 'HMMV DST=10 Y=1022-1 (バンク内で折り返す)', 0, 10, C_HMMV, dx=0, dy=1022, nx=256, ny=4, clr=0xC5)
	BT(g, sc8, 'LMMV XOR DST=7', 7, 7, C_LMMV | 3, dx=33, dy=900, nx=70, ny=3, clr=0x5B, guard=nbanks(7))
	BT(g, sc8, 'HMMM SRC=3 DST=12 (同じ座標)', 3, 12, C_HMMM, sx=1, sy=700, dx=1, dy=700, nx=255, ny=3)
	BT(g, sc8, 'HMMM SRC=9 Y=510-513 -> DST=6 Y=1022-1', 9, 6, C_HMMM, sx=0, sy=510, dx=0, dy=1022, nx=256, ny=4)
	BT(g, sc8, 'LMMM TIMP SRC=14 DST=1', 14, 1, C_LMMM | 8, sx=5, sy=800, dx=9, dy=600, nx=90, ny=3)
	BT(g, sc8, 'YMMM SRC=11 DST=4', 11, 4, C_YMMM, sy=300, dx=64, dy=300, ny=3)
	BT(g, sc8, 'LMCM SRC=13 (DST=2)', 13, 2, C_LMCM, sx=10, sy=1000, nx=8, ny=2, guard=(2, 12, 0))
	BT(g, sc8, 'POINT SRC=6 (DST=9)', 6, 9, C_POINT, sx=77, sy=1023, guard=(9, 7, 14, 0))
	BT(g, sc8, 'PSET XOR DST=3 (SRC=12 は使わない)', 12, 3, C_PSET | 3, dx=200, dy=777, clr=0xA5)
	BT(g, sc8, 'LINE DST=14 (SRC=1)', 1, 14, C_LINE, dx=20, dy=505, nx=80, ny=9, clr=0xD3)
	BT(g, sc8, 'LMMC DST=5 (SRC=10)', 10, 5, C_LMMC, dx=50, dy=1020, nx=6, ny=3)
	BT(g, sc8, 'HMMC DST=12 Y=1023-0', 0, 12, C_HMMC, dx=17, dy=1023, nx=8, ny=2)
	srch_bank_case(g, sc8, 'SRCH SRC=9: バンクごとに異なる X に目標色', 600, 9, (0, 8, 11, 1), 0x9A, False)

	g.sub('VDP コマンド (R#30) その他の画面モード')
	sc6, sc7 = mode('SCREEN6'), mode('SCREEN7')
	BT(g, sc6, 'LMMV DST=13 Y=1022-1025', 0, 13, C_LMMV, dx=100, dy=1022, nx=300, ny=4, clr=0x02)
	BT(g, sc7, 'HMMV DST=11 Y=510-513', 0, 11, C_HMMV, dx=0, dy=510, nx=512, ny=4, clr=0x4E)
	BT(g, sc7, 'HMMM SRC=2 DST=13 Y=1023-0', 2, 13, C_HMMM, sx=4, sy=200, dx=4, dy=1023, nx=300, ny=2)
	BT(g, mode('SCREEN8', fg4=True), 'HMMV DST=9 Y=1022-1025 (SCREEN5 相当)', 0, 9, C_HMMV,
		dx=0, dy=1022, nx=256, ny=4, clr=0x7C)
	BT(g, mode('SCREEN8', fg4=True), 'LMMM SRC=3 Y=2047 -> DST=12 Y=0', 3, 12, C_LMMM, sx=0, sy=2047, dx=0, dy=0,
		nx=256, ny=1)


def suite_bank_mix(g):
	sc5, sc8 = mode('SCREEN5'), mode('SCREEN8')
	g.sub('CPU と VDP コマンドのバンクを変えて同じアドレスへアクセス')
	for m, y in ((sc5, 400), (sc8, 200)):
		rb = GEOM[m.geom][3]
		g.begin('CPU がバンク 3 に書いた直後に HMMM が SRC=7 の同アドレスを読む', m)
		banks(g, cpu=3, src=7, dst=8)
		g.cmd(C_HMMM, sx=0, sy=y, dx=0, dy=y + 300, nx=256, ny=2, guard=(3, 0, 9),
			before=lambda: (g.cpur(y * rb, 0x20), g.cpuw(y * rb, rb * 2, 0x71), g.cpur(y * rb + 0x10, 0x20)))
		g.end()

	for m, y in ((sc5, 600), (sc8, 300)):
		rb = GEOM[m.geom][3]
		a = y * rb
		regs = [(a - rb, rb * 4)]
		bks = (12, 13, 4, 0)
		g.begin('CPU(12) 書込 -> HMMV(13) -> CPU(12) 書込 -> HMMC(13) -> LMMV(12) を順に同アドレスへ', m)
		banks(g, cpu=12, src=0, dst=13)
		fill_banks(g, bks, regs)
		g.cpuw(a, rb * 2, 0x72)
		g.cmd(C_HMMV, dx=0, dy=y, nx=256, ny=2, clr=0x1E, autofill=False, check=False)
		g.cpur(a, 0x40)
		g.cpuw(a + 0x20, rb, 0x73)
		g.cmd(C_HMMC, dx=16, dy=y + 1, nx=32, ny=1, autofill=False, check=False)
		g.cpur(a + 0x10, rb)
		g.set_cmd_banks(12, 12)
		g.cmd(C_LMMV | 3, dx=8, dy=y, nx=20, ny=2, clr=0x0F, autofill=False, check=False)
		g.cpur(a, 0x40)
		read_banks(g, bks, regs)
		g.end()

	g.sub('VDP コマンド実行中に別バンクを CPU でアクセス')
	for m, y in ((sc5, 200), (sc8, 100)):
		rb = GEOM[m.geom][3]
		a = y * rb
		a2 = (y + 100) * rb

		def mid(a=a, a2=a2, rb=rb):
			g.cpuw(a, 0x200, 0x74)
			g.cpur(a, 0x200)
			g.set_cpu_bank(9)
			g.cpuw(a2, 0x100, 0x75)
			g.set_cpu_bank(6)

		def pre(a2=a2, rb=rb):
			g.set_cpu_bank(9)
			g.fillp(a2 - rb, 0x100 + 2 * rb, g.bank_seed(9))
			g.set_cpu_bank(6)

		g.begin('HMMV(DST=9) 実行中に CPU がバンク 6 の同アドレスとバンク 9 の別ラインを読み書き', m)
		banks(g, cpu=6, src=0, dst=9)
		g.cmd(C_HMMV, dx=0, dy=y, nx=256, ny=8, clr=0x8B, guard=(6, 1, 8), before=pre, between=mid)
		g.set_cpu_bank(9)
		g.read(a2 - rb, 0x100 + 2 * rb)
		g.end()

		def mid2(a=a, rb=rb):
			g.cpur(a, 0x100)
			g.set_cpu_bank(4)
			g.cpuw(a, 0x100, 0x76)
			g.set_cpu_bank(5)
			g.cpuw(a + 0x40, 0x100, 0x77)
			g.set_cpu_bank(4)
			g.cpur(a, 0x100)
			g.set_cpu_bank(2)

		g.begin('HMMM(SRC=2 DST=3) 実行中に CPU が R#28 を 2/4/5 と切り替えて同アドレスを読み書き', m)
		banks(g, cpu=2, src=2, dst=3)
		g.cmd(C_HMMM, sx=0, sy=y, dx=0, dy=y, nx=256, ny=8, guard=(4, 5, 1, 7), between=mid2)
		g.end()

	g.begin('LMMV TIMP(DST=10) 実行中に CPU がバンク 11 へ書き、読み戻す', sc5)
	banks(g, cpu=11, src=0, dst=10)
	g.cmd(C_LMMV | 8, dx=3, dy=1030, nx=250, ny=4, clr=0x07, guard=(11, 2, 14),
		between=lambda: (g.cpuw(1030 * 128, 0x200, 0x78), g.cpur(1029 * 128, 0x300)))
	g.end()


SPR = {
	# name: (R#5, R#11, R#6, attribute, color, pattern)
	'SCREEN5': (0xEF, 0x00, 0x0F, 0x7600, 0x7400, 0x7800),
	'SCREEN8': (0xF7, 0x01, 0x1E, 0xFA00, 0xF800, 0xF000),
}


def spr_tables(g, m, bk, hit):
	"""sprite mode 2 tables in bank bk: hit = sprites 0 and 1 overlap at (100, 50), else no sprite"""
	_, _, _, sat, col, pat = SPR[m.name]
	cpu = g.cpu_bank
	g.set_cpu_bank(bk)
	if hit:
		g.fillc(pat, 8, 0xFF)
		g.fillc(col, 32, 0x0F)
		for i, x in enumerate((100, 103)):
			g.fillc(sat + i * 4, 1, 50)
			g.fillc(sat + i * 4 + 1, 1, x)
			g.fillc(sat + i * 4 + 2, 2, 0)
		g.fillc(sat + 8, 1, 216)
	else:
		g.fillc(sat, 1, 216)
	g.set_cpu_bank(cpu)


def spr_case(g, m, desc, hit_banks, miss_banks, r29, cpu=0, cmdb=0, expect=True):
	r5, r11, r6, _, _, _ = SPR[m.name]
	g.begin(desc, m)
	banks(g, cpu, cmdb, cmdb)
	g.reg(29, 0x00)
	for bk in hit_banks:
		spr_tables(g, m, bk, True)
	for bk in miss_banks:
		spr_tables(g, m, bk, False)
	g.reg(5, r5)
	g.reg(11, r11)
	g.reg(6, r6)
	g.reg(29, r29)
	g.reg(8, 0x08)				# sprites on
	g.frame()
	g.stat(0, 0x20, 0x20 if expect else 0)
	g.reg(8, 0x0A)
	g.reg(29, 0x00)
	g.end()


def suite_bank_sprite(g):
	g.sub('スプライト (R#29 上位 4 ビット): S#0 の衝突フラグで確認')
	for name in ('SCREEN5', 'SCREEN8'):
		m = mode(name)
		spr_case(g, m, 'R#29=00h: バンク 0 の衝突するスプライト', (0,), (), 0x00)
		spr_case(g, m, 'R#29=90h: バンク 9 だけに衝突するスプライト', (9,), (0,), 0x90)
		spr_case(g, m, 'R#29=09h: BG バンク=9 ではスプライトはバンク 0 (衝突なし)', (9,), (0,), 0x09, expect=False)
		spr_case(g, m, 'R#29=60h: バンク 0 だけ衝突、バンク 6 は無し (衝突なし)', (0,), (6,), 0x60, expect=False)
		if name == 'SCREEN5':
			spr_case(g, m, 'R#29=F6h: バンク 15 だけに衝突するスプライト', (15,), (0, 7), 0xF6)
			spr_case(g, m, 'R#29=E0h, R#28=R#30=バンク 15 (衝突あり): スプライトは 14', (15,), (14,), 0xE0,
				cpu=15, cmdb=15, expect=False)


def LT(g, m, desc, src, dst, font, dx, dy, nx, ny, fg, bg, lop=0):
	"""LFMM: font at CPU-view address font in bank src, drawn into bank dst.
	The font area holds a different pattern in every guard bank, so a font read
	from a wrong bank changes the drawing; the guard banks must stay unchanged."""
	guard = sorted(set(nbanks(src) + nbanks(dst) + (0,)) - {src, dst})
	BT(g, m, desc, src, dst, C_LFMM | lop, guard=guard, sx=font & 0xFFFF, sy=font >> 16,
		dx=dx, dy=dy, nx=nx, ny=ny, clr=fg, bg=bg)


def suite_bank_lfmm(g):
	sc5, sc8 = mode('SCREEN5'), mode('SCREEN8')
	g.sub('LFMM (フォントは R#30 SRC バンク、描画は DST バンク)')
	LT(g, sc5, 'SRC=DST=0 フォント 01000h', 0, 0, 0x01000, 16, 100, 4, 8, 0x0F, 0x04)
	LT(g, sc5, 'SRC=3 DST=12 フォント 10000h', 3, 12, 0x10000, 16, 100, 4, 8, 0x0F, 0x04)
	LT(g, sc5, 'SRC=12 DST=3 (逆向き)', 12, 3, 0x10000, 16, 100, 4, 8, 0x0F, 0x04)
	LT(g, sc5, 'SRC=DST=9 フォント 0F000h -> Y=200', 9, 9, 0x0F000, 40, 200, 3, 16, 0x0A, 0x05)
	LT(g, sc5, 'SRC=15 DST=0', 15, 0, 0x2A5A0, 0, 0, 5, 8, 0x0E, 0x01)
	LT(g, sc5, 'SRC=0 DST=15 Y=2040', 0, 15, 0x00800, 200, 2040, 7, 8, 0x0C, 0x03)
	LT(g, sc5, 'SRC=6 DST=1 フォント 1FFF8h (128KB 境界をまたぐ)', 6, 1, 0x1FFF8, 64, 1022, 2, 8, 0x0D, 0x02)
	LT(g, sc5, 'SRC=10 DST=5 フォント 3FFF8h (バンク内で 00000h へ折り返す)', 10, 5, 0x3FFF8, 64, 1500, 2, 8,
		0x09, 0x06)
	LT(g, sc5, 'TIMP BG=0 SRC=2 DST=13', 2, 13, 0x34567, 8, 333, 4, 8, 0x0B, 0x00, lop=8)
	LT(g, sc5, 'XOR SRC=11 DST=4', 11, 4, 0x05555, 120, 1800, 3, 8, 0x07, 0x0C, lop=3)
	LT(g, sc8, 'SCREEN8 SRC=7 DST=8 フォント 00123h (インターリーブ)', 7, 8, 0x00123, 40, 500, 3, 8, 0xE3, 0x1C)
	LT(g, sc8, 'SCREEN8 SRC=13 DST=2 フォント 1FFFCh', 13, 2, 0x1FFFC, 0, 1016, 2, 8, 0x5A, 0xA5)
	LT(g, sc8, 'SCREEN8 SRC=14 DST=1 フォント 3FFF9h (折り返し)', 14, 1, 0x3FFF9, 248, 0, 1, 16, 0xFF, 0x00)
	LT(g, mode('SCREEN7'), 'SCREEN7 SRC=4 DST=11 フォント 20001h', 4, 11, 0x20001, 480, 1000, 4, 8, 0x0F, 0x08)
	LT(g, mode('SCREEN6'), 'SCREEN6 SRC=12 DST=3', 12, 3, 0x0ABCD, 256, 1020, 8, 8, 0x03, 0x01)


def suite_bank(g):
	suite_bank_regs(g)
	suite_bank_cpu(g)
	suite_bank_cmd(g)
	suite_bank_mix(g)
	suite_bank_sprite(g)
	suite_bank_lfmm(g)


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

	g.section('VRAM 4MB バンク R#28/R#29/R#30 (V9968 のみ)', v9968_only=True)
	suite_bank(g)
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
		f.write('- VRAM バンクの節は全バンクにバンクごとに異なるパターンを書き、対象バンクとバンク番号が 1 ビット違うバンク'
			'(ガード) も読み戻して、別バンクの同じアドレスが壊れていないことを確認します。'
			'R#29 (スプライト) は 1 フレーム表示させて S#0 の衝突フラグで確認します。'
			'LFMM はフォントを SRC バンク、描画先を DST バンクに置き、ガードバンクの同じアドレスには別のフォントを置いて確認します。'
			'BG バンク (表示のみ)、コマンド実行中の R#30 変更は自動確認の対象外です。\n')
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
