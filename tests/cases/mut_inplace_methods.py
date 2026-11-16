def sorted_copy(values: list[int]) -> list[int]:
    result = values[:]
    result.sort()
    return result


def sort_in_place(values: list[int]) -> list[int]:
    values.sort()
    return values


def swap_ends(values: list[int]) -> list[int]:
    values[0], values[-1] = values[-1], values[0]
    return values


def drain(stack: list[int]) -> int:
    total = 0
    while stack:
        total += stack.pop()
    return total


def group(numbers: list[int]) -> dict[int, list[int]]:
    groups: dict[int, list[int]] = {}
    for number in numbers:
        key = number % 3
        if key not in groups:
            groups[key] = []
        groups[key].append(number)
    return groups


def collect(prefix: int, out: list[int]) -> None:
    out.append(prefix)
    if prefix < 3:
        collect(prefix + 1, out)


def gather() -> list[int]:
    found = []
    collect(1, found)
    return found


unsorted = [5, 3, 9, 1]
print(sorted_copy(unsorted))
print(sort_in_place(unsorted))
letters = [4, 5, 6]
letters.reverse()
print(letters)
print(swap_ends(letters))
pending = [1, 2, 3]
print(drain(pending), len(pending))
print(group([1, 2, 3, 4, 5, 6, 7]))
print(gather())
scratch = [7, 8]
scratch.clear()
print(len(scratch))
