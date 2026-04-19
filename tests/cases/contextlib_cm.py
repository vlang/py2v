#!/usr/bin/env python3
"""Test contextlib.contextmanager decorator → V defer pattern."""

from contextlib import contextmanager


@contextmanager
def managed_file(path):
    f = open(path, 'r')
    try:
        yield f
    finally:
        f.close()


def open_and_read(path):
    with managed_file(path) as f:
        return f.read()

