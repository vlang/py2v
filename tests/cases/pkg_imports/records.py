from dataclasses import dataclass


@dataclass
class RawResult:
    status: int
    stdout: str
    stderr: str = ""


def describe(raw: RawResult) -> str:
    return f"{raw.status}:{raw.stdout}:{raw.stderr}"
