def split_nul(payload: str) -> list[str]:
    return payload.split("\x00")


def strip_bell(line: str) -> str:
    return line.replace("\x07", "")


def has_vertical_tab(ch: str) -> bool:
    return "\x0b" in ch


def delimiter() -> str:
    return "\x1f"


def unit_separator_fields(record: str) -> list[str]:
    return record.split("\x1f")


ESCAPE_8BIT = "\xff"

RAW_TEXT = "plain text with no control characters"