def text() -> str:
    print("text")
    return "-é🙂"


def width() -> int:
    print("width")
    return 6


print(text().zfill(width()))
print("+9".zfill(5))
print("é".zfill(5))
print("".zfill(5))
print("-".zfill(2))
print("ok".zfill(-1))
