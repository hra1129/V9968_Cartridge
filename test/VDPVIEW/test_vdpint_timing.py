"""Exercise the assembled VDPINT interrupt window with a simulated Z80."""

from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from z80 import Z80Machine


HERE = Path(__file__).resolve().parent
FRAME_TICKS = 59736
LINE_TICKS = 228
LINE_AFTER_FRAME = 176
# From the frame IRQ to the last 192-line border case and the next 212-line Y=0.
LATEST_BOTTOM = 32 * LINE_TICKS + LINE_AFTER_FRAME
EARLIEST_TOP = (262 - 211) * LINE_TICKS + LINE_AFTER_FRAME


class InterruptRun:
    def __init__(self, binary, symbols, lines, y, *, first=1000, r23=200,
                 m1_wait=1, io_wait=0, drop=None, extra=None, add_hits=0):
        self.symbols = symbols
        self.cpu = Z80Machine()
        self.cpu.set_memory_block(0x100, binary)
        isr = symbols['edge_isr']
        wait = symbols['edge_wait']
        self.cpu.memory[0x38:0x3B] = bytes([0xC3, isr & 0xFF, isr >> 8])
        self.cpu.memory[0x80:0x86] = bytes([0xED, 0x56, 0xFB, 0xC3, wait & 0xFF, wait >> 8])
        self.cpu.pc = 0x80
        self.cpu.sp = 0xE000
        self.cpu.memory[symbols['edge_lines']] = lines
        self.cpu.memory[symbols['edge_y']] = y
        self.cpu.memory[symbols['edge_r23']] = r23
        self.cpu.memory[symbols['edge_r19']] = (y + r23) & 0xFF
        self.cpu.set_input_callback(self.input_port)
        self.cpu.set_output_callback(self.output_port)

        self.time = 0
        self.last_tick = self.cpu.frame_tick
        self.next_frame = first
        self.next_line = first + ((y - (lines - 1)) % 262) * LINE_TICKS + LINE_AFTER_FRAME
        self.frame_events = 0
        self.line_events = 0
        self.line_reads = 0
        self.frame_flag = False
        self.line_flag = False
        self.drop = drop
        self.extra = extra
        self.extra_time = None
        self.add_hits = add_hits
        self.m1_wait = m1_wait
        self.io_wait = io_wait
        self.status = 0
        self.control_first = None
        self.vram_high = 0
        self.vram_address = None
        self.vram = bytearray(0x40000)
        self.colour = None
        self.samples = []

    def input_port(self, port):
        port &= 0xFF
        if port in (0xA9, 0xAA):
            return 0xFF
        if port != 0x99:
            raise AssertionError(f'Unexpected input port {port:02X}')
        self.time += self.io_wait
        self.control_first = None
        if self.status == 0:
            value = 0x80 if self.frame_flag else 0
            self.frame_flag = False
            return value
        if self.status == 1:
            value = int(self.line_flag)
            self.line_reads += value
            self.line_flag = False
            return value
        raise AssertionError(f'Unexpected status register {self.status}')

    def output_port(self, port, value):
        port &= 0xFF
        if port == 0xAA:
            return
        if port == 0x98:
            self.time += self.io_wait
            if self.vram_address is None:
                raise AssertionError('VRAM write without an address')
            self.vram[self.vram_address] = value
            self.vram_address = (self.vram_address + 1) & 0x3FFFF
            return
        if port != 0x99:
            raise AssertionError(f'Unexpected output port {port:02X}')
        self.time += self.io_wait
        if self.control_first is None:
            self.control_first = value
            return
        first, self.control_first = self.control_first, None
        if value & 0x80:
            reg = value & 0x3F
            if reg == 7:
                self.colour = first
            elif reg == 14:
                self.vram_high = first & 0x0F
            elif reg == 15:
                self.status = first & 0x0F
            else:
                raise AssertionError(f'Unexpected register write R#{reg}')
        elif value & 0xC0 == 0x40:
            self.vram_address = (self.vram_high << 14) | ((value & 0x3F) << 8) | first
        else:
            raise AssertionError(f'Unexpected VDP control byte {value:02X}')

    def advance(self):
        tick = self.cpu.frame_tick
        # Z80Machine wraps frame_tick every 100000 T-states.
        self.time += (tick - self.last_tick) % 100000
        self.last_tick = tick

    def run(self, hold_frames=0):
        result_frame = None
        while self.time < (70 + hold_frames) * FRAME_TICKS:
            if self.time >= self.next_frame:
                self.frame_events += 1
                self.frame_flag = True
                self.next_frame += FRAME_TICKS
            if self.time >= self.next_line:
                self.line_events += 1
                if self.line_events != self.drop:
                    self.line_flag = True
                if self.line_events == self.extra:
                    self.extra_time = self.next_line + 2000
                self.next_line += FRAME_TICKS
            if self.extra_time is not None and self.time >= self.extra_time:
                self.line_flag = True
                self.extra_time = None
            if (self.frame_flag or self.line_flag) and self.cpu.iff1 and not self.cpu.int_disabled:
                self.cpu.on_handle_active_int()
                self.advance()

            if self.cpu.pc == self.symbols['edge_sample_lock']:
                phase = self.cpu.memory[self.symbols['edge_phase']]
                self.samples.append((phase, self.time - (self.next_frame - FRAME_TICKS)))
                if phase == 66 and self.add_hits:
                    address = self.symbols['edge_hits']
                    hits = int.from_bytes(self.cpu.memory[address:address + 2], 'little')
                    self.cpu.memory[address:address + 2] = (hits + self.add_hits).to_bytes(2, 'little')
            if self.cpu.pc == self.symbols['edge_sample_end'] and (self.done or self.failed):
                if result_frame is None:
                    result_frame = self.frame_events
                if self.done or not hold_frames:
                    return
            if result_frame is not None and self.frame_events >= result_frame + hold_frames:
                return

            self.cpu.ticks_to_stop = 1
            opcode = self.cpu.memory[self.cpu.pc]
            self.cpu.run()
            self.advance()
            self.time += self.m1_wait * (2 if opcode in (0xCB, 0xDD, 0xED, 0xFD) else 1)
        raise AssertionError(f'Interrupt run timed out at PC={self.cpu.pc:04X}')

    @property
    def done(self):
        return self.cpu.memory[self.symbols['edge_done']]

    @property
    def failed(self):
        return self.cpu.memory[self.symbols['edge_failed']]

    @property
    def hits(self):
        address = self.symbols['edge_hits']
        return int.from_bytes(self.cpu.memory[address:address + 2], 'little')


class VdpIntTimingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(temp.cleanup)
        directory = Path(temp.name)
        for name in ('VDPVIEW.ASM', 'VDPINT.INC'):
            shutil.copyfile(HERE / name, directory / name)
        result = subprocess.run(
            [str(HERE.parents[1] / 'tool' / 'zma.exe'),
             '-DEDGE_TEST=1', 'VDPVIEW.ASM', 'VDPINT.COM'],
            cwd=directory, capture_output=True, text=True,
        )
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        cls.binary = (directory / 'VDPINT.COM').read_bytes()
        if cls.binary != (HERE / 'VDPINT.COM').read_bytes():
            raise AssertionError('VDPINT.COM does not match the assembled source')
        cls.symbols = {
            match.group(1).lower(): int(match.group(2), 16)
            for match in re.finditer(r'^(\w+)\s+equ\s+0*([0-9a-f]+)h$',
                                     (directory / 'zma.sym').read_text(), re.M | re.I)
        }

    def simulate(self, lines, y, **kwargs):
        app = InterruptRun(self.binary, self.symbols, lines, y, **kwargs)
        app.run()
        return app

    def assert_count_display(self, app, count):
        r23 = app.cpu.memory[self.symbols['edge_r23']]
        start = ((r23 + 80) & 0xFF) * 128 + 32 + 39
        font = self.symbols['edge_hex_font']
        for digit_index, shift in enumerate((12, 8, 4, 0)):
            digit = (count >> shift) & 0x0F
            for row in range(7):
                address = start + digit_index * 3 + row * 128
                expected = font + digit * 21 + row * 3
                self.assertEqual(bytes(app.vram[address:address + 3]),
                                 bytes(app.cpu.memory[expected:expected + 3]))

    def test_all_edge_lines_have_a_safe_sampling_window(self):
        for lines, border in ((192, (208, 216, 223)), (212, (223, 230, 234))):
            ys = list(range(8)) + list(range(lines - 5, lines + 4)) + list(border)
            for index, y in enumerate(ys):
                with self.subTest(lines=lines, y=y):
                    app = self.simulate(lines, y, first=1000 + (index * 37) % 600,
                                        io_wait=index % 2, r23=(0, 1, 64, 200, 255)[index % 5])
                    self.assertTrue(app.done)
                    self.assertFalse(app.failed)
                    self.assertEqual(app.hits, 64)
                    self.assertEqual([phase for phase, _ in app.samples], [2, 66])
                    for _, tick in app.samples:
                        self.assertGreater(tick, LATEST_BOTTOM)
                        self.assertLess(tick, EARLIEST_TOP)

    def test_old_race_and_wait_state_extremes(self):
        cases = (
            (212, 223, 1040, 1, 0),
            (212, 223, 1080, 1, 1),
            (192, 223, 1000, 0, 0),
            (212, 0, 1280, 2, 2),
        )
        for lines, y, first, m1_wait, io_wait in cases:
            with self.subTest(lines=lines, y=y, first=first, m1_wait=m1_wait, io_wait=io_wait):
                app = self.simulate(lines, y, first=first, m1_wait=m1_wait, io_wait=io_wait)
                self.assertTrue(app.done)
                self.assertFalse(app.failed)
                self.assertEqual(app.hits, 64)
                if y == 223 and lines == 212:
                    self.assertEqual(app.line_events, 66)
                    self.assertEqual(app.line_reads, 66)
                for _, tick in app.samples:
                    self.assertGreater(tick, LATEST_BOTTOM)
                    self.assertLess(tick, EARLIEST_TOP)

    def test_one_missing_or_extra_interrupt_is_reported(self):
        for drop, extra, expected in ((3, None, 63), (34, None, 63),
                                      (66, None, 63), (None, 34, 65)):
            with self.subTest(drop=drop, extra=extra):
                app = self.simulate(212, 223, first=1280, drop=drop, extra=extra)
                self.assertTrue(app.failed)
                self.assertFalse(app.done)
                self.assertEqual(app.hits, expected)
                self.assertEqual(app.colour, 8)
                self.assert_count_display(app, expected)

    def test_first_failure_count_is_preserved(self):
        app = InterruptRun(self.binary, self.symbols, 212, 223, drop=34, r23=255)
        app.run(hold_frames=270)
        self.assertTrue(app.failed)
        self.assertFalse(app.done)
        self.assertEqual([phase for phase, _ in app.samples], [2, 66])
        self.assert_count_display(app, 63)

    def test_count_display_includes_the_high_byte(self):
        app = self.simulate(212, 223, add_hits=0x100)
        self.assertTrue(app.failed)
        self.assertEqual(app.hits, 0x140)
        self.assert_count_display(app, 0x140)


if __name__ == '__main__':
    unittest.main()
