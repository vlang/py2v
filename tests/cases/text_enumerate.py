def show_characters(text: str) -> None:
    for offset, char in enumerate(text):
        print(offset, char, char == "♞")


if __name__ == "__main__":
    show_characters("é♞a")
