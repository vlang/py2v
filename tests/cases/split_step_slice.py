def take(text: str, stride: int) -> list[str]:
    return text.split(",")[::stride]


def main() -> None:
    print("/".join(take("alpha,beta,gamma,delta", -2)))
    texts = ["red,green,blue", "a,b,c,d,e"]
    print("/".join(texts[0].split(",")[::-1]))
    print("/".join(texts[1].split(",")[4:0:-2]))
    parts = take(texts[1], 1)
    print("/".join(parts[1:4:2]))


if __name__ == "__main__":
    main()
