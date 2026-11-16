import logging

_logger = logging.getLogger("app.b")
_LIMIT = 5


def run_b(n: int) -> int:
    _logger.warning("b %d", n)
    return n * _LIMIT
