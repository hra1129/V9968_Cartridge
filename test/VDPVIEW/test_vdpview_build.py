"""Check that the scanline interrupt test stays a separate, small executable."""

from pathlib import Path
import re
import unittest

import gen_vdpview


HERE = Path(__file__).resolve().parent


class VdpViewBuildTest(unittest.TestCase):
    def test_interrupt_pages_are_in_the_separate_executable(self):
        gen_vdpview.PAGES.clear()
        gen_vdpview.build_line_edge_pages()
        interrupt_com = (HERE / 'VDPINT.COM').read_bytes()
        view_com = (HERE / 'VDPVIEW.COM').read_bytes()

        self.assertEqual(len(gen_vdpview.PAGES), 4)
        self.assertLess(len(interrupt_com), 8 * 1024)
        for page in gen_vdpview.PAGES:
            with self.subTest(page=page.title):
                code = bytes(page.code())
                self.assertEqual(interrupt_com.count(code), 1)
                self.assertNotIn(code, view_com)

    def test_interrupt_page_table_skips_extended_modes_on_v9958(self):
        include = (HERE / 'VDPINT.INC').read_text(encoding='ascii')
        table = re.search(r'page_count::\s+db\s+4\s+page_table::(.*?)page_19:',
                          include, re.DOTALL)
        self.assertIsNotNone(table)
        entries = re.findall(r'db\s+([01])\s+dw\s+(page_\d+)', table.group(1))
        self.assertEqual(entries, [
            ('0', 'page_19'), ('0', 'page_20'),
            ('1', 'page_21'), ('1', 'page_22'),
        ])


if __name__ == '__main__':
    unittest.main()
