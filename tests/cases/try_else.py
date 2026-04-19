def demo(ok: bool):
    try:
        if not ok:
            raise ValueError("bad")
        print("try")
    except ValueError as e:
        print("except")
    else:
        print("else")
    finally:
        print("finally")


if __name__ == "__main__":
    demo(True)
    demo(False)

