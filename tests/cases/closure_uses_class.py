class Token:
    def __init__(self, text: str, quoted: bool) -> None:
        self.text = text
        self.quoted = quoted


def tokenize(src: str) -> list[Token]:
    tokens: list[Token] = []
    cur = ""

    def end_token() -> None:
        nonlocal cur
        if cur != "":
            tokens.append(Token(cur, False))
            cur = ""

    for ch in src:
        if ch == " ":
            end_token()
        else:
            cur += ch
    end_token()
    return tokens


for token in tokenize("ab c"):
    print(token.text, token.quoted)
