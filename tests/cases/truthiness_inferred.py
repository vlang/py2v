def describe(name: str, items: list[int], count: int, ratio: float) -> str:
    parts = []
    if name:
        parts.append("named")
    if not items:
        parts.append("no items")
    if count and items:
        parts.append("counted")
    if not ratio or not name:
        parts.append("zero or anonymous")
    left = count
    while left:
        left -= 1
    label = "some" if items else "none"
    parts.append(label)
    return ",".join(parts)


def tally(words: list[str]) -> dict[str, int]:
    seen = {}
    for word in words:
        if word:
            seen[word] = len(word)
    if not seen:
        seen["empty"] = 0
    return seen


empty: list[int] = []
full: list[int] = [1]
some_words: list[str] = ["a", "", "bb"]
no_words: list[str] = []
print(describe("x", full, 2, 0.5))
print(describe("", empty, 0, 0.0))
print(tally(some_words))
print(tally(no_words))
