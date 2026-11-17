"""Typing casts must retain value evaluation and unsafe type-expression evaluation."""
import ast
from pathlib import Path
import sys
import unittest
from unittest import mock

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
            "from typing import cast\nanswer = cast(str | None, 1)",
            "from typing import cast\nanswer = cast(None | (str | int), 1)",
            "from typing import cast\nanswer = cast(list['TextContent'], 1)",
            "from typing import cast\nanswer = cast(tuple['bad syntax !', ...], 1)",
            "from typing import cast, Optional\nanswer = cast(Optional, 1)",
            "from typing import cast, List\nanswer = cast(List[list['bad syntax !']], 1)",
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
            "from .typing import cast\nanswer = cast(float, 1)",
            "from typing import cast, List\nanswer = cast(List['bad syntax !'], 1)",
            "from typing import cast, List, Optional\nanswer = cast(List[Optional], 1)",
            "from typing import cast\nanswer = cast(None | None, 1)",
            "from typing import cast\nanswer = cast((None | None) | int, 1)",
            "from typing import cast\nanswer = cast(UserType | None, 1)",
            "from typing import cast\nstr = custom\nanswer = cast(str | None, 1)",
            "from typing import cast, Optional, Union\nanswer = cast(Optional[Union], 1)",
            "from typing import cast, Callable, Optional\nanswer = cast(Callable[[Optional], int], 1)",
            "from typing import cast, Tuple\nanswer = cast(Tuple['bad syntax !', ...], 1)",
        ]
        for source in sources:
            with self.subTest(source=source):
                self.assertIsInstance(self.transformed_value(source), ast.Call)

    def test_value_call_is_preserved_once(self) -> None:
        value = self.transformed_value("from typing import cast\nanswer = cast(int, produce())")
        self.assertEqual(ast.dump(value), ast.dump(ast.parse("produce()", mode="eval").body))

    def test_typing_arguments_can_raise_before_cast(self) -> None:
        from typing import List, Optional, cast
        invalid_reference = "bad syntax !"
        self.assertEqual(cast(list[invalid_reference], 1), 1)
        with self.assertRaises(SyntaxError):
            cast(List[invalid_reference], 1)
        with self.assertRaises(TypeError):
            cast(List[Optional], 1)

    def test_union_requires_python_support(self) -> None:
        with mock.patch.object(ast_dump.sys, "version_info", (3, 9)):
            value = self.transformed_value("from typing import cast\nanswer = cast(str | None, 1)")
            self.assertIsInstance(value, ast.Call)

    def test_union_can_run_custom_code(self) -> None:
        from typing import cast
        effects: list[str] = []

        class Meta(type):
            def __or__(cls, other: object) -> type:
                effects.append("type")
                return cls

        class Claimed(metaclass=Meta):
            pass

        def produce() -> int:
            effects.append("value")
            return 4

        self.assertEqual(cast(Claimed | None, produce()), 4)
        self.assertEqual(effects, ["type", "value"])


if __name__ == "__main__":
    unittest.main()
