"""Typing casts must retain value evaluation and unsafe type-expression evaluation."""
import ast
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "frontend"))
import ast_dump


class TypingCastTest(unittest.TestCase):
    def transformed_value(self, source: str) -> ast.expr:
        tree = ast.parse(source)
        table = ast_dump._resolve_bindings(tree)
        ast_dump._erase_typing_casts(tree, table)
        assignments = [stmt for stmt in tree.body if isinstance(stmt, ast.Assign)]
        if not assignments:
            raise AssertionError("expected final assignment")
        return assignments[-1].value

    def test_static_type_erasure(self) -> None:
        sources = [
            "from typing import cast\nanswer = cast(float, 1)",
            "from typing import cast as claim\nanswer = claim(list[int], 1)",
            "import typing as hints\nanswer = hints.cast(hints.Any, 1)",
            "from typing import cast, Any\nanswer = cast(dict[str, Any], 1)",
            "from typing import cast, Callable, Any\nanswer = cast(Callable[..., Any], 1)",
            "from typing import cast\nanswer = cast('unknown type', 1)",
        ]
        for source in sources:
            with self.subTest(source=source):
                value = self.transformed_value(source)
                self.assertIsInstance(value, ast.Constant)
                self.assertEqual(value.value, 1)

    def test_unsafe_type_expressions_and_bindings_stay(self) -> None:
        sources = [
            "from typing import cast\nanswer = cast(make_type(), 1)",
            "from typing import cast\nanswer = cast(UserType[int], 1)",
            "from typing import cast, List\nanswer = cast(List[int, str], 1)",
            "from typing import cast\ncast = other\nanswer = cast(float, 1)",
            "import other as hints\nanswer = hints.cast(float, 1)",
            "if flag:\n    from typing import cast\nanswer = cast(float, 1)",
            "import typing\ntyping.cast = other\nanswer = typing.cast(float, 1)",
            "import typing\ndel typing.Any\nanswer = typing.cast(typing.Any, 1)",
            "answer = cast(float, 1)\nfrom typing import cast",
        ]
        for source in sources:
            with self.subTest(source=source):
                self.assertIsInstance(self.transformed_value(source), ast.Call)

    def test_value_call_is_preserved_once(self) -> None:
        value = self.transformed_value("from typing import cast\nanswer = cast(int, produce())")
        self.assertEqual(ast.dump(value), ast.dump(ast.parse("produce()", mode="eval").body))


if __name__ == "__main__":
    unittest.main()
