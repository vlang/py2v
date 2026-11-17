import sys
from sys import exit as finish


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
