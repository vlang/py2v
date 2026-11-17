import argparse


def separator() -> str:
    print("separator")
    return "|"


def main() -> None:
    parser = argparse.ArgumentParser(prog="join-test")
    parser.add_argument("words", nargs="*")
    parser.add_argument("--numbers", nargs="*", type=int)
    empty = parser.parse_args([])
    print(" ".join(empty.words))
    args = parser.parse_args(["alpha", "β"])
    print(" ".join(args.words))
    print(separator().join(args.words))
    print("".join(args.words))
    one = parser.parse_args(["z"])
    print(" - ".join(one.words))
    invalid = parser.parse_args(["--numbers", "1", "2"])
    try:
        print(" ".join(invalid.numbers))
    except TypeError:
        print("type-error")
    try:
        print(separator().join(args.missing))
    except AttributeError:
        print("missing")


if __name__ == "__main__":
    main()
