def describe(point):
    match point:
        case [0, 0]:
            return "origin"
        case [x, 0]:
            return f"on x-axis at {x}"
        case [0, y]:
            return f"on y-axis at {y}"
        case [x, y]:
            return f"at ({x}, {y})"
        case _:
            return "not a point"


def parse_command(command: dict) -> str:
    match command:
        case {"action": "quit"}:
            return "quitting"
        case {"action": "move", "direction": direction}:
            return f"moving {direction}"
        case _:
            return "unknown command"


def check_guard(n: int) -> str:
    match n:
        case x if x < 0:
            return "negative"
        case 0:
            return "zero"
        case x if x > 100:
            return "large"
        case _:
            return "normal"


if __name__ == "__main__":
    print(describe([0, 0]))
    print(describe([3, 0]))
    print(describe([1, 2]))
    print(parse_command({"action": "quit"}))
    print(check_guard(-5))
    print(check_guard(0))
    print(check_guard(200))
    print(check_guard(42))

