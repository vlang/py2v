#!/usr/bin/env python3

import logging


def process():
    logging.basicConfig()
    logging.info("starting")
    logging.debug("x=42")
    logging.warning("low memory")
    logging.warn("also a warning")
    logging.error("failed")
    logging.critical("shutdown")
    logging.exception("caught error")


if __name__ == "__main__":
    process()
