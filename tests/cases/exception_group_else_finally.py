def handle(ok: bool):
    try:
        if ok:
            print("ok")
        else:
            raise ExceptionGroup("eg", [ValueError("v")])
    except* ValueError as eg:
        print("caught value group")
    else:
        print("no group")
    finally:
        print("cleanup")


if __name__ == "__main__":
    handle(True)
    handle(False)

