def or_gate(input_1: int, input_2: int) -> int:
    return int((input_1, input_2).count(1) != 0)


def zeros(a: float, b: float, c: float) -> int:
    return (a, b, c).count(0)


def main() -> None:
    print(or_gate(0, 0))
    print(or_gate(1, 0))
    print(zeros(0, 2.5, 0))
    xs = [1, 2, 2, 3, 2]
    print(xs.count(2))
    print([4, 4, 5].count(4))
    names = ["a", "b", "a"]
    print(names.count("a"))
    word = "banana"
    print(word.count("a"))
    print("abcabc".count("bc"))


if __name__ == "__main__":
    main()
