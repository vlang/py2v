import logging

_logger = logging.getLogger("app.a")
_LIMIT = 3


def run_a(n: int) -> int:
    _logger.info("a %d", n)
    return n + _LIMIT
