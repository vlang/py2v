#!/usr/bin/env python3
# errno, stat, signal and warnings are rewritten at the use site: they have no
# V module import, and V exposes neither errno constants nor stat predicates.


import errno
import os
import signal
import stat
import warnings


def is_dir(mode: int) -> bool:
    return stat.S_ISDIR(mode)


def is_regular(mode: int) -> bool:
    return stat.S_ISREG(mode)


def is_link(mode: int) -> bool:
    return stat.S_ISLNK(mode)


def is_fifo(mode: int) -> bool:
    return stat.S_ISFIFO(mode)


def setuid(mode: int) -> bool:
    return stat.S_ISUID(mode)


def permissions(mode: int) -> int:
    return stat.S_IMODE(mode)


def missing() -> bool:
    return errno.ENOENT == 2


def stale() -> int:
    return errno.ESTALE


def denied() -> int:
    return errno.EACCES


def term_handler() -> bool:
    return signal.SIGTERM == signal.SIGTERM


def on_term() -> None:
    signal.signal(signal.SIGTERM, on_term)


def flag(msg: str) -> None:
    warnings.warn("deprecated")
    warnings.warn(msg)
