def at(text: str, index: int) -> str:
    return text[index]


word = "aé😀"
print(at(word, 1), at(word, -1))
print(word[-2], word[2])
for char in reversed(word):
    print(char)
for index, char in enumerate(word):
    print(char == word[index])
print(int(list("12")[1]), list(word)[-1])
