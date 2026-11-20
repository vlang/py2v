def pad(text: str, width: int, fill: str) -> str:
    return text.center(width, fill)


print(pad("éà", 5, "🙂"), pad("é", 4, "🙂"), pad("é", 0, "🙂"), sep="|")
print("".center(3, "ø"))
