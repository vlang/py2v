from dataclasses import dataclass
from typing import Any, Optional


@dataclass
class Outcome:
    stop_reason: Optional[str] = None
    meta: Optional[dict] = None
    count: Optional[int] = None


def describe(o: Outcome, note: Optional[str], extra: Any) -> str:
    parts = []
    if o.stop_reason:
        parts.append("stopped:" + o.stop_reason)
    if not o.meta:
        parts.append("no-meta")
    if o.count:
        parts.append("counted")
    if note:
        parts.append("note:" + note)
    if extra:
        parts.append("extra")
    if o.stop_reason and note:
        parts.append("both")
    return ",".join(parts)


def main() -> None:
    print(describe(Outcome(), None, 0))
    print(describe(Outcome(stop_reason="limit", count=0), "", "x"))
    print(describe(Outcome(stop_reason="", meta={"a": 1}, count=3), "n", []))


if __name__ == "__main__":
    main()
