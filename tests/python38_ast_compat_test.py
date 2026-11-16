"""Exercise the Python 3.8 frontend API without requiring a second interpreter."""

import ast
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "frontend"))
import ast_dump


class MissingUnparseTest(unittest.TestCase):
    def test_annotated_module_without_unparse(self):
        source = """from __future__ import annotations
from typing import Any, Optional

class Item:
    name: Optional[str]
    fields: dict[str, Any]

def f(x: int) -> int:
    return x + 1

print(f(2))
"""
        with TemporaryDirectory() as td:
            path = Path(td) / "sample.py"
            path.write_text(source, encoding="utf-8")
            modern = json.loads(ast_dump.process_file(str(path))) if hasattr(ast, "unparse") else None
            original = getattr(ast, "unparse", None)
            if original is not None:
                del ast.unparse
            try:
                legacy = json.loads(ast_dump.process_file(str(path)))
                self.assertEqual(ast_dump._unparse_expr(ast.parse("dict[str, Any]", mode="eval").body),
                                 "dict[str, Any]")
                self.assertEqual(ast_dump._unparse_expr(ast.parse("str | None", mode="eval").body),
                                 "str | None")
            finally:
                if original is not None:
                    ast.unparse = original
            if modern is not None:
                self.assertEqual(legacy, modern)


if __name__ == "__main__":
    unittest.main()
