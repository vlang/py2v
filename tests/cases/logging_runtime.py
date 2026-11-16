import logging
import sys

logger = logging.getLogger(__name__)


def work(n: int, name: str) -> int:
    logger.debug("starting %s", name)
    logger.info("processing %d items for %s", n, name)
    if n > 2:
        logger.warning("large batch: %d", n)
    logger.error("done %s with ratio %.2f", name, n / 3)
    return n * 2


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s", stream=sys.stdout)
    print(work(3, "alpha"))
    logger.info("plain message")


if __name__ == "__main__":
    main()
