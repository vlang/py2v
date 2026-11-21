def describe(values: list[str]) -> str:
    return "|".join(map(repr, values))

if __name__ == "__main__":
    print(describe(["plain", "it's", "\nß"]))
