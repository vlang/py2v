"""Prove the incoming assignment rules independently of emitted V syntax."""

import ast
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "frontend"))
import ast_dump


class DefiniteAssignmentTest(unittest.TestCase):
    def check_path(self, body: str, expected: bool) -> None:
        source = "def collect(flag: bool):\n" + "\n".join("    " + line for line in body.splitlines())
        tree = ast.parse(source)
        ast_dump._resolve_bindings(tree)
        fn = tree.body[0]
        if not isinstance(fn, ast.FunctionDef):
            raise AssertionError("expected one function")
        proven = ast_dump._definitely_assigned_loads(fn)
        loads = [node for comp in ast.walk(fn) if isinstance(comp, ast.ListComp)
                 for node in ast.walk(comp) if isinstance(node, ast.Name)
                 and isinstance(node.ctx, ast.Load) and node.id == "values"]
        self.assertTrue(loads)
        self.assertEqual(all(id(node) in proven for node in loads), expected)

    def test_proven_paths(self) -> None:
        bodies = [
            "if flag:\n    values = [1]\nelse:\n    values = [2]\nreturn [v for v in values]",
            "if flag:\n    return []\nelse:\n    values = [2]\nreturn [v for v in values]",
            "try:\n    values = [1]\nexcept ValueError:\n    values = [2]\nreturn [v for v in values]",
            "try:\n    values = [1]\nexcept ValueError:\n    return []\nreturn [v for v in values]",
            "for i in [1]:\n    values = [i]\nreturn [v for v in values]",
            "while True:\n    values = [1]\n    break\nreturn [v for v in values]",
            "try:\n    pass\nfinally:\n    values = [1]\nreturn [v for v in values]",
        ]
        for body in bodies:
            with self.subTest(body=body):
                self.check_path(body, True)

    def test_unproven_paths(self) -> None:
        bodies = [
            "if flag:\n    values = [1]\nreturn [v for v in values]",
            "try:\n    values = [1]\nexcept ValueError:\n    pass\nreturn [v for v in values]",
            "try:\n    values = [1]\nfinally:\n    result = [v for v in values]",
            "for i in []:\n    values = [i]\nreturn [v for v in values]",
            "for i in [*[]]:\n    values = [i]\nreturn [v for v in values]",
            "for i in flag:\n    values = [i]\nreturn [v for v in values]",
            "for i in [1]:\n    if flag:\n        break\n    values = [i]\nreturn [v for v in values]",
            "for i in [1]:\n    if flag:\n        continue\n    values = [i]\nreturn [v for v in values]",
            "while flag:\n    values = [1]\nreturn [v for v in values]",
            "with flag:\n    values = [1]\nreturn [v for v in values]",
            "values = [1]\nfor i in [1, 2]:\n    result = [v for v in values]\n    del values",
            "values: list[int]\nreturn [v for v in values]",
            "while True:\n    try:\n        values = [1]\n    finally:\n        if flag:\n            break\n        result = [2]\n    break\nreturn [v for v in result] + [v for v in values]",
        ]
        for body in bodies:
            with self.subTest(body=body):
                self.check_path(body, False)

    def test_augmented_assignment_reads_before_writing(self) -> None:
        tree = ast.parse("def collect(flag):\n    if flag:\n        values = [1]\n    else:\n        values += [2]\n    return [v for v in values]\n")
        ast_dump._resolve_bindings(tree)
        fn = tree.body[0]
        if not isinstance(fn, ast.FunctionDef):
            raise AssertionError("expected one function")
        proven = ast_dump._definitely_assigned_loads(fn)
        augmented = [node.target for node in ast.walk(fn) if isinstance(node, ast.AugAssign)]
        self.assertEqual(len(augmented), 1)
        self.assertNotIn(id(augmented[0]), proven)


if __name__ == "__main__":
    unittest.main()
