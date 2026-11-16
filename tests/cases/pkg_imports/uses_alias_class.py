from . import records as rec


def check(code: int) -> str:
    return rec.describe(rec.RawResult(code, "out", "err"))
