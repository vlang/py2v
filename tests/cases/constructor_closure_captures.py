class Pair:
    def __init__(self, left: int, right: int) -> None:
        self.left = left
        self.right = right


class Token:
    def __init__(self, text: str, quoted: bool) -> None:
        self.text = text
        self.quoted = quoted


def scalar_capture() -> None:
    value = 4

    def build() -> Pair:
        return Pair(value + 1, value * 2)

    pair = build()
    print(pair.left, pair.right)


def token_capture() -> None:
    letters = ["a", "b"]
    quoted = True

    def build() -> Token:
        return Token("".join(letters), quoted)

    token = build()
    print(token.text, token.quoted)


def mutable_capture() -> None:
    items = [3, 7]

    def build() -> Pair:
        return Pair(items.pop(), len(items))

    pair = build()
    print(pair.left, pair.right, len(items))


def nested_capture() -> None:
    value = 6

    def middle() -> Pair:
        def build() -> Pair:
            return Pair(value + 2, value + 3)

        return build()

    pair = middle()
    print(pair.left, pair.right)


def keyword_capture() -> None:
    items = [2, 9]

    def build() -> Pair:
        return Pair(right=len(items), left=items.pop())

    pair = build()
    print(pair.left, pair.right, len(items))


scalar_capture()
token_capture()
mutable_capture()
nested_capture()
keyword_capture()
