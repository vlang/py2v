from typing import Tuple, Literal


def coords() -> Tuple[int, int]:
    return (1, 2)


def rgb() -> Tuple[int, int, int]:
    return (255, 0, 128)


def mixed() -> Tuple[int, str]:
    return (1, "hello")


def variable_len() -> Tuple[int, ...]:
    return (1, 2, 3)


Direction = Literal["north", "south", "east", "west"]
Speed = Literal[1, 2, 3, 4, 5]


def move(direction: str, speed: int) -> None:
    print(direction, speed)


move("north", 3)

