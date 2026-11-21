def char_at(text: str, index: int) -> str:
    return text[index]

def is_drop(text: str) -> bool:
    return "@" == text[1]

if __name__ == "__main__":
    print(char_at("é♞n", 1))
    print(char_at("é♞n", -3))
    print(is_drop("P@e4"))
    print(int("v4"[1]))
    try:
        print(char_at("fa", 12))
    except IndexError:
        print("out of range")
