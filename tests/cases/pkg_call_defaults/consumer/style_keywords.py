from ..styles import styled


def run_style_keywords() -> None:
    styled("line", fg="red", weight=2)
    styled(newline=False, suffix=None)
    styled()
