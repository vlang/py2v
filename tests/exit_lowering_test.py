"""Only resolved exit statements in supported exception contexts may be lowered."""
import ast
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "frontend"))
import ast_dump


class ExitLoweringTest(unittest.TestCase):
    def lowered_count(self, source: str) -> int:
        tree = ast.parse(source)
        table = ast_dump._resolve_bindings(tree)
        ast_dump._lower_exit_statements(tree, table)
        return sum(isinstance(node, ast.Raise) for node in ast.walk(tree))

    def test_resolved_calls(self) -> None:
        for source in ["exit()", "quit(None)", "import sys as system\nsystem.exit(2)",
                       "from sys import exit as finish\nfinish('message')"]:
            with self.subTest(source=source):
                self.assertEqual(self.lowered_count(source), 1)

    def test_unsafe_contexts_and_bindings_stay(self) -> None:
        for source in [
            "def exit(code): pass\nexit(1)",
            "from sys import exit\nexit = custom\nexit(1)",
            "import sys\nsys.exit = custom\nsys.exit(1)",
            "sys.exit(1)\nimport sys",
            "if flag:\n    import sys\nsys.exit(1)",
            "try:\n    exit(1)\nfinally:\n    cleanup()",
            "with manager():\n    exit(1)",
            "exit(*codes)", "exit(code=1)", "exit(1, 2)",
            "SystemExit = custom\nexit(1)",
        ]:
            with self.subTest(source=source):
                self.assertEqual(self.lowered_count(source), 0)


if __name__ == "__main__":
    unittest.main()
