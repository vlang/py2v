import os


def pick() -> str:
    a = os.environ.get("PY2V_UNSET_A") or os.environ.get("HOME")
    if a is None:
        return "none"
    return a


def flag() -> bool:
    previous = os.environ.get("PY2V_UNSET_B")
    if previous:
        return True
    if os.environ.get("HOME"):
        return previous is None
    return False


def named() -> str:
    name = os.getenv("PY2V_UNSET_C")
    return name if name is not None else "unset"


def fallback() -> str:
    return os.environ.get("PY2V_UNSET_D") or "default"


def chain() -> str:
    return os.getenv("PY2V_UNSET_E") or os.environ.get("PY2V_UNSET_F") or "last"


def absent() -> bool:
    return not os.environ.get("PY2V_UNSET_G") and os.environ.get("PY2V_UNSET_H", "x") == "x"


if __name__ == "__main__":
    print(len(pick()) > 0)
    print(flag())
    print(named())
    print(fallback())
    print(chain())
    print(absent())
