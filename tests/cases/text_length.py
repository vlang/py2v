def codepoints(text: str) -> int:
    return len(text)


if __name__ == "__main__":
    text = "ae\u0301😀e\u0301"
    print(len(text))
    print(codepoints(text))
    print(codepoints(""))
    print(len(["é", "😀"]))
