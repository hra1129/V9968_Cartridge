#!/usr/bin/env python3
"""Build the transition stress diagnostic using the VDPVIEW interpreter."""

import os
from pathlib import Path
import re
import subprocess
import tempfile

from gen_vdpview import FONT


HERE = Path(__file__).resolve().parent
ZMA = HERE.parent.parent / 'tool' / 'zma.exe'

WAIT_ACTION = """\
wait_action:
\t\tld\t\ta, 1
\t\tld\t\t[vv_ready], a
wait_action_loop:
\t\tcall\tget_key
\t\tor\t\ta, a
\t\tjr\t\tz, wait_action_loop
\t\tld\t\t[action], a
\t\txor\t\ta, a
\t\tld\t\t[vv_ready], a
\t\tret
"""

WREG = """\
wreg:
\t\tout\t\t[VDP_CTRL], a
\t\tld\t\ta, b
\t\tor\t\ta, 0x80
\t\tout\t\t[VDP_CTRL], a
\t\tret
"""

WAIT_CE = """\
wait_ce:
\t\tld\t\ta, 2
\t\tld\t\tb, 15
\t\tcall\twreg
wait_ce_loop:
\t\tin\t\ta, [VDP_CTRL]
\t\trrca
\t\tjr\t\tc, wait_ce_loop
\t\txor\t\ta, a
\t\tld\t\tb, 15
\t\tjp\t\twreg
"""

PREPARE_START = """\
page_prepare:
\t\tdi
\t\txor\t\ta, a
\t\tld\t\tb, 1
\t\tcall\twreg\t\t\t; display off, no interrupts
"""

PREPARE_CLEAR = """\
page_prepare_clear:
\t\tld\t\thl, cmd_clear0
\t\tcall\tvdp_cmd36
\t\tld\t\thl, cmd_clear1
\t\tjp\t\tvdp_cmd36
"""

DIAG_PREPARE_CLEAR = """\
page_prepare_clear:
\t\tld\t\ta, 0x05
\t\tcall\tdiag_mark
\t\tld\t\thl, cmd_clear0
\t\tcall\tvdp_cmd36
\t\tld\t\ta, 0x08
\t\tcall\tdiag_mark
\t\tld\t\thl, cmd_clear1
\t\tcall\tvdp_cmd36
\t\tld\t\ta, 0x0A
\t\tcall\tdiag_mark
\t\tret
"""

DIAG_ENTRY = """\
vdp_ok:
\t\tcall\tturbo_r_z80
\t\tcall\tdiag_run
finish:
\t\tcall\trestore_screen
\t\tei
\t\tcall\tturbo_r_restore
\t\tcall\tdiag_report
"""


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('VDPVIEW.ASM changed: cannot locate diagnostic hook')
    return source.replace(old, new)


def diagnostic_font():
    lines = ['diag_font:']
    for ch in '0123456789AB':
        rows = [value << 3 for value in FONT[ch]] + [0]
        lines.append('\t\tdb\t\t' + ', '.join('0x%02X' % v for v in rows) + ' ; ' + ch)
    return '\n'.join(lines) + '\n'


def diagnostic_pages(pages, keep):
    """Keep page_table, but replace unused page bodies with op_end to save TPA."""
    out = []
    skipping = False
    for line in pages.splitlines(keepends=True):
        match = re.match(r'(page_\d+):', line)
        if match:
            skipping = match.group(1) not in keep
            out.append(line)
            if skipping:
                out.append('\t\tdb\t\t0\n')
            continue
        if not skipping:
            out.append(line)
    return ''.join(out)


def main():
    source = (HERE / 'VDPVIEW.ASM').read_text(encoding='ascii')
    pages = (HERE / 'VDPVIEW.INC').read_text(encoding='ascii')
    for label, title in (
            ('page_05', 'SC8 SPRITE M2 8X8 X2'),
            ('page_06', 'SC5 SPRITE COLOR'),
            ('page_10', 'SC5 LINE INT BORDER'),
            ('page_11', 'SC5 LINE INT SCROLL')):
        if pages.count('%s:\t\t; %s\n' % (label, title)) != 1:
            raise ValueError('VDPVIEW.INC changed: update the diagnostic page numbers')
    start = 'vdp_ok:\n'
    end = 'exit_dos:\n'
    if source.count(start) != 1 or source.count(end) != 1:
        raise ValueError('VDPVIEW.ASM changed: cannot locate diagnostic entry')
    before, rest = source.split(start)
    _, after = rest.split(end)
    source = before + DIAG_ENTRY + end + after
    source = replace_once(source, WAIT_ACTION, 'wait_action:\n\t\tjp\t\tdiag_wait_action\n')
    source = replace_once(source, WREG, 'wreg:\n\t\tjp\t\tdiag_wreg\n')
    source = replace_once(source, WAIT_CE, 'wait_ce:\n\t\tjp\t\tdiag_wait_ce\n')
    source = replace_once(source, PREPARE_START, PREPARE_START +
                          '\t\tld\t\ta, 0x03\n\t\tcall\tdiag_mark\n')
    source = replace_once(source, PREPARE_CLEAR, DIAG_PREPARE_CLEAR)
    source = replace_once(source, 'op_show:\n\t\tdi\n\t\tjp\t\twait_action\n',
                          'op_show:\n\t\tdi\n\t\tcall\tdiag_draw\n\t\tjp\t\twait_action\n')
    source = replace_once(source, 'op_line:\n', 'op_line:\n\t\tdi\n\t\tcall\tdiag_draw\n')
    source = replace_once(source, 'VDPVIEW - VDP visual check',
                          'VDPDIAG - transition stress')
    source = replace_once(source, 'SPACE/RET/RIGHT:next  BS/LEFT:back  ESC:quit',
                          '1:P11->P12  2:P06->P07  ESC:quit')
    include = '\t\tinclude\t"VDPVIEW.INC"\n'
    name = None
    page_name = None
    try:
        with tempfile.NamedTemporaryFile(
                mode='w', encoding='ascii', newline='\n',
                prefix='vdpdiag_', suffix='.inc', dir=HERE, delete=False) as f:
            page_name = f.name
            f.write(diagnostic_pages(pages, {'page_05', 'page_06', 'page_10', 'page_11'}))
        source = replace_once(source, include,
                              '\t\tinclude\t"VDPDIAG.ASM"\n' + diagnostic_font() +
                              '\t\tinclude\t"%s"\n' % Path(page_name).name)
        with tempfile.NamedTemporaryFile(
                mode='w', encoding='ascii', newline='\n',
                prefix='vdpdiag_', suffix='.asm', dir=HERE, delete=False) as f:
            name = f.name
            f.write(source)
        subprocess.run([str(ZMA), '-DEDGE_TEST=0', name, 'VDPDIAG.COM'], cwd=HERE, check=True)
    finally:
        for path in (name, page_name):
            if path is not None:
                os.unlink(path)


if __name__ == '__main__':
    main()
