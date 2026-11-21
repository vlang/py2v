from typing import Sequence


def render_words(words: Sequence[str], label: str | None = None) -> str:
    if label is not None:
        return label + "=" + ":".join(words)
    return "words=" + ":".join(words)


if __name__ == "__main__":
    print(render_words(["one", "two"], "custom"))
    print(render_words("éx"))
