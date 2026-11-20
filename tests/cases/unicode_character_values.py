def at(text: str, index: int) -> str:
    return text[index]


word = "aé😀"
print(at(word, 1), at(word, -1))
print(word[-2], word[2])
for char in reversed(word):
    print(char)
