#!/usr/bin/env python3


def show(ranks: dict[str, int], rank: int, words: list[str]) -> None:
    name = next((k for k, v in ranks.items() if v == rank), None)
    if name is None:
        print("no name")
    else:
        print(name)
    long_word = next((w for w in words if len(w) > 3), "none")
    print(long_word)
    print(next((w.upper() for w in words if w.startswith("z")), "nothing"))
    missing = next((k for k, v in ranks.items() if v > 99), None)
    print(missing is None)


if __name__ == "__main__":
    show({"a": 1, "b": 2}, 2, ["ab", "abcd", "zed"])
