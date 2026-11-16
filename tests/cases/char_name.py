def shout(char: str) -> str:
    return char.upper() + "!"


def count_vowels(text: str) -> int:
    total = 0
    for char in text:
        if char in "aeiou":
            total += 1
    return total


def main() -> None:
    print(shout("a"))
    print(count_vowels("education"))
    char = "z"
    print(char)
    letters = [char for char in "xyz"]
    print(letters)


if __name__ == "__main__":
    main()
