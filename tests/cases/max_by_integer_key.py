from dataclasses import dataclass
from enum import Enum


@dataclass
class Entry:
    name: str
    score: int


class Rank(Enum):
    LOW = 1
    HIGH = 4

    def points(self) -> int:
        return self.value


def winner(items: list[Entry]) -> Entry:
    return max(items, key=lambda entry: entry.score)


def highest(ranks: set[Rank]) -> Rank:
    return max(ranks, key=lambda rank: rank.value)


if __name__ == "__main__":
    print(winner([Entry("low", 1), Entry("first", 4), Entry("tied", 4)]).name)
    print(highest({Rank.HIGH, Rank.LOW}).points())
    try:
        winner([])
    except ValueError:
        print("empty")
