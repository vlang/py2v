def handle(flag: bool):
    try:
        if flag:
            raise ExceptionGroup("mixed", [ValueError("v"), TypeError("t")])
        print("no raise")
    except* ValueError as eg:
        print("caught value")
    except* TypeError as eg:
        print("caught type")


if __name__ == "__main__":
    handle(True)
    handle(False)

