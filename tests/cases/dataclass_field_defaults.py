from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Policy:
    name: str
    tags: list[str] = field(default_factory=list)
    limits: dict[str, int] = field(default_factory=dict)
    retries: int = 3
    note: Optional[str] = None
    weight: float = field(default=1.5)
    seen: set[str] = field(default_factory=set)


def main() -> None:
    a = Policy("a")
    b = Policy("b", tags=["x"], retries=5)
    a.tags.append("only-a")
    a.limits["cpu"] = 2
    print(a.name, a.tags, a.limits, a.retries, a.note is None, a.weight)
    print(b.name, b.tags, b.limits, b.retries, b.weight)
    print(len(a.seen))


if __name__ == "__main__":
    main()
