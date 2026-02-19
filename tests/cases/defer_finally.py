#!/usr/bin/env python3


def pure_finally() -> int:
    """try/finally without except should produce clean defer."""
    result = 0
    try:
        result = 42
    finally:
        print("cleanup")
    return result


def nested_finally() -> int:
    """Nested try/finally blocks each get their own defer."""
    try:
        try:
            x = 10
        finally:
            print("inner cleanup")
    finally:
        print("outer cleanup")
    return x


def mixed_handlers():
    """try/except/finally should defer the finally and comment the except."""
    try:
        value = int("123")
        print(value)
    except ValueError as e:
        print("bad value")
    finally:
        print("done")


def multi_stmt_finally():
    """Multiple statements in finally all go inside a single defer block."""
    resource = None
    try:
        resource = 1
    finally:
        print("step 1")
        print("step 2")
        resource = None


if __name__ == "__main__":
    print(pure_finally())
    print(nested_finally())
    mixed_handlers()
    multi_stmt_finally()
