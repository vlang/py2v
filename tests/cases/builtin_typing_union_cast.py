from typing import cast

if __name__ == "__main__":
    print(cast(int | None, 1))
    print(cast(str | None, "word"))
    print(cast(None | int, 2))
    print(cast((str | int) | None, 3))
    print(cast(None | (str | int), 7))
