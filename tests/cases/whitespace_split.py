def split_text(text: str) -> list[str]:
    return text.split()


def main() -> None:
    print(len(split_text("")))
    print("|".join(split_text(" \t\n\r\v\f\x1c\x1d\x1e\x1f\x85\u00a0\u1680\u2003\u2028\u2029\u202f\u205f\u3000")))
    texts = ["  hello\tworld  ", "\u2003δοκιμή\u202f猫\n", "abc\x00\u200bdef"]
    print("|".join(split_text(texts[0])))
    print("|".join(texts[1].split()))
    print("|".join(split_text(texts[2])) == texts[2])
    print("|".join("a  b ".split(" ")))


if __name__ == "__main__":
    main()
