from typing import Optional


def text(label: str, value: Optional[str]) -> Optional[str]:
    print(label)
    return value


if __name__ == "__main__":
    if text("none", None):
        print("bad-none")
    if not text("empty", ""):
        print("empty")
    print(1 if text("set", "yes") else 0)
    while text("loop", None):
        print("bad-loop")
    print(not (text("first", "") or text("second", "ok")))
