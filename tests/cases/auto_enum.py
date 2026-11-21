import enum


class Termination(enum.Enum):
    """Why a game ended."""

    CHECKMATE = enum.auto()
    """The king cannot escape."""
    STALEMATE = enum.auto()
    """There is no legal move."""


if __name__ == "__main__":
    print(Termination.CHECKMATE)
    print(Termination.STALEMATE)
    print(Termination.CHECKMATE == Termination.STALEMATE)
