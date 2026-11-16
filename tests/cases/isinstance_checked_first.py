def highest_bit(number: int) -> int:
    if not isinstance(number, int):
        raise TypeError("Input value must be an 'int' type")
    position = 0
    while number:
        position += 1
        number >>= 1
    return position


def rotate(x: int, k: int) -> int:
    if not isinstance(x, int) or x < 0:
        raise ValueError("x must be non-negative")
    if not isinstance(k, int) or k < 0:
        raise ValueError("k must be non-negative")
    k &= 31
    return (x << k) & 0xFFFF


def as_text(num: int) -> str:
    if isinstance(num, float):
        raise TypeError("float given")
    if isinstance(num, (str, bytes, tuple, set)):
        raise TypeError("not a number")
    if num < 0:
        num = -num
    return str(num)


def all_ints(arr: list[int]) -> bool:
    return all(isinstance(x, int) for x in arr)


def count_ints(inputs: list[int]) -> int:
    if not isinstance(inputs, (list, tuple)):
        raise TypeError("a list is needed")
    total = 0
    for item in inputs:
        if not isinstance(item, int):
            raise TypeError("All inputs in the list must be integers")
        total += 1
    return total


def joined(separator: str, separated: list[str]) -> str:
    out = ""
    for word in separated:
        if not isinstance(word, str):
            raise Exception("join() accepts only strings")
        out += word + separator
    return out


def scaled(theta: float, accuracy: int = 30) -> float:
    if not isinstance(theta, (int, float)):
        raise ValueError("an int or float is needed")
    if not isinstance(accuracy, int) or accuracy <= 0:
        raise ValueError("a positive int is needed")
    theta = theta * 2
    return theta + accuracy


print(highest_bit(25))
print(rotate(3, 2))
print(as_text(-7))
print(all_ints([1, 2, 3]))
print(count_ints([1, 0, 1]))
print(joined("-", ["a", "b"]))
print(scaled(1.5, 2))


def twice(words: list[str]) -> int:
    n = 0
    for w in words:
        if not isinstance(w, str):
            raise Exception("only strings")
    for w in words[:1]:
        n += len(w)
    return n


print(twice(["ab", "c"]))
