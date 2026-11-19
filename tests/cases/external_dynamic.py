from __future__ import annotations

try:
    import py2v_fixture_missing_dependency as external
except ImportError:
    pass


class Wrapper:
    value: external.Context


def from_context(value: external.Context) -> str:
    return value.upper()


def lookup():
    return external.make(value=1)


print(from_context("ready"))
