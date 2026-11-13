class Token:
    _type: str = "word"
    name: str = ""

    def kind(self) -> str:
        return self._type


def main() -> None:
    t = Token()
    print(t.kind())


if __name__ == "__main__":
    main()
