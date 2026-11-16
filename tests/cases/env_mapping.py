#!/usr/bin/env python3
import os


def show() -> None:
    os.environ["PY2V_SET_A"] = "one"
    print(os.environ["PY2V_SET_A"])
    print("PY2V_SET_A" in os.environ)
    os.environ.pop("PY2V_SET_A", None)
    print("PY2V_SET_A" in os.environ, "PY2V_SET_A" not in os.environ)
    print(os.environ.setdefault("PY2V_SET_B", "two"))
    print(os.environ.setdefault("PY2V_SET_B", "three"))
    print(os.environ.get("PY2V_SET_B", None) is None)
    del os.environ["PY2V_SET_B"]
    print(os.environ.get("PY2V_SET_B") is None)
    env = dict(os.environ)
    env["PY2V_SET_C"] = "1"
    print(env["PY2V_SET_C"], "PY2V_SET_C" in os.environ)
    other = os.environ.copy()
    print("PY2V_SET_C" in other, len(other) > 0)


if __name__ == "__main__":
    show()
