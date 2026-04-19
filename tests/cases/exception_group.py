import sys


def handle():
    try:
        raise ExceptionGroup("multiple", [ValueError("v"), TypeError("t")])
    except* ValueError as eg:
        print("caught value error group")
    except* TypeError as eg:
        print("caught type error group")


handle()

