import re
import time

WORD = re.compile(r"[a-z]+")


def show(text: str) -> None:
    start = time.time()
    m = re.search(r"(\d+)-(\d+)", text)
    if m:
        print(m.group(1), m.group(2), m.group(0))
    print(WORD.findall(text))
    print(re.sub(r"\d", "#", text))
    print(WORD.sub("w", text))
    parts = re.split(r"\s+", text)
    print(len(parts))
    found = WORD.match(text)
    print(found is None)
    print(bool(re.fullmatch(r"\d+", "123")))
    elapsed = time.time() - start
    print(elapsed >= 0.0, time.monotonic() > 0)


if __name__ == "__main__":
    show("10-20 abc def 7")
