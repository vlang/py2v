from dataclasses import dataclass
from typing import TypeAlias

Square: TypeAlias = int

@dataclass(unsafe_hash=True)
class Move:
    source: Square
    target: Square
    promotion: int | None = None

    def __bool__(self) -> bool:
        return bool(self.source or self.target or self.promotion)

    def label(self) -> str:
        return "present" if self else "empty"

if __name__ == "__main__":
    print(Move(0, 0).label())
    print(Move(1, 0).label())
    print(Move(0, 0, 3).label())
