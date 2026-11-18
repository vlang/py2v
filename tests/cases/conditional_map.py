def choose(flag: bool, key: str) -> dict[str, int]:
    return {key: 3} if flag else {key: 7}


if __name__ == "__main__":
    print(choose(True, "x"))
    print(choose(False, "x"))
