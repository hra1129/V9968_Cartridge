#!/usr/bin/env python3
"""Build a CE-wait diagnostic from the same source and pages as VDPVIEW."""

import os
from pathlib import Path
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
ZMA = HERE.parent.parent / 'tool' / 'zma.exe'

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

DIAG_WAIT_CE = """\
wait_ce:
\t\tpush\tbc
\t\tpush\tde
\t\tld\t\ta, 2
\t\tld\t\tb, 15
\t\tcall\twreg
\t\tld\t\tbc, 0
\t\tld\t\td, 16
wait_ce_loop:
\t\tin\t\ta, [VDP_CTRL]
\t\trrca
\t\tjr\t\tnc, wait_ce_done
\t\tdec\t\tbc
\t\tld\t\ta, b
\t\tor\t\ta, c
\t\tjr\t\tnz, wait_ce_loop
\t\tdec\t\td
\t\tjr\t\tnz, wait_ce_loop
\t\tpop\t\tde
\t\tpop\t\tbc
diag_flash:
\t\tld\t\ta, [diag_color]
\t\txor\t\ta, 0xFF
\t\tld\t\t[diag_color], a
\t\tld\t\tb, 7
\t\tcall\twreg
\t\tld\t\tbc, 0
diag_delay:
\t\tdec\t\tbc
\t\tld\t\ta, b
\t\tor\t\ta, c
\t\tjr\t\tnz, diag_delay
\t\tjr\t\tdiag_flash
wait_ce_done:
\t\tpop\t\tde
\t\tpop\t\tbc
\t\txor\t\ta, a
\t\tld\t\tb, 15
\t\tjp\t\twreg
diag_color:
\t\tdb\t\t0
"""


def main():
    source = (HERE / 'VDPVIEW.ASM').read_text(encoding='ascii')
    banner = 'VDPVIEW - VDP visual check'
    if source.count(WAIT_CE) != 1 or source.count(banner) != 1:
        raise ValueError('VDPVIEW.ASM changed: update the diagnostic substitutions')
    source = source.replace(WAIT_CE, DIAG_WAIT_CE)
    source = source.replace(banner, 'VDPDIAG - CE wait diagnostic')
    name = None
    try:
        with tempfile.NamedTemporaryFile(
                mode='w', encoding='ascii', newline='\n',
                prefix='vdpdiag_', suffix='.asm', dir=HERE, delete=False) as f:
            name = f.name
            f.write(source)
        subprocess.run([str(ZMA), name, 'VDPDIAG.COM'], cwd=HERE, check=True)
    finally:
        if name is not None:
            os.unlink(name)


if __name__ == '__main__':
    main()
