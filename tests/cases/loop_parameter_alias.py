class Box:
    def __init__(self, value: int):
        self.value = value


def rebind_box(value: Box) -> int:
    for value in [Box(3), Box(4)]:
        break
    return 0


def mutate_then_rebind(value: Box) -> int:
    value.value = 9
    for value in [Box(3)]:
        pass
    return 0


def rebind_list(value: list[int]) -> int:
    for value in [[3, 4]]:
        pass
    return 0


def run() -> None:
    original = Box(7)
    items = [7, 8]
    rebind_box(original)
    rebind_list(items)
    print(original.value)
    print(items[0])
    second = Box(7)
    mutate_then_rebind(second)
    print(second.value)


if __name__ == "__main__":
    run()
