import sys
from sys import exit as finish


def exit_argument() -> int:
    print("argument evaluated")
    return 4


def direct_finally() -> None:
    try:
        raise SystemExit("direct message")
    finally:
        print("direct cleanup")


def sys_finally() -> None:
    try:
        sys.exit(exit_argument())
    finally:
        print("sys cleanup")


def nested_finally() -> None:
    try:
        try:
            raise SystemExit(2)
        finally:
            raise SystemExit(3)
    finally:
        print("outer cleanup")


def nested_cleanups() -> None:
    try:
        try:
            raise SystemExit(2)
        finally:
            print("inner cleanup")
    finally:
        print("outer cleanup")


def caught() -> None:
    try:
        exit(3)
    except SystemExit as error:
        print("caught", error)
    try:
        finish("message")
    except Exception:
        print("wrong")
    except BaseException as error:
        print("base", error)
    try:
        sys.exit()
    except SystemExit:
        print("default")
    try:
        quit(None)
    except SystemExit:
        print("none")


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "caught":
        caught()
    elif mode == "zero":
        exit()
    elif mode == "int":
        finish(7)
    elif mode == "true":
        sys.exit(True)
    elif mode == "false":
        exit(False)
    elif mode == "none":
        quit(None)
    elif mode == "message":
        exit("message")
    elif mode == "direct_finally":
        direct_finally()
    elif mode == "sys_finally":
        sys_finally()
    elif mode == "nested_finally":
        nested_finally()
    elif mode == "nested_cleanups":
        nested_cleanups()
