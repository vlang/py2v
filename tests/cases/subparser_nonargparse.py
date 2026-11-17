import argparse


class CustomBuilder:
    def add_parser(self, name: str) -> str:
        return "custom:" + name


def add_custom(builder):
    return builder.add_parser("x")


def add_real(subparsers):
    subparsers.add_parser("real")


def exercise() -> None:
    parser = argparse.ArgumentParser()
    action = parser.add_subparsers(dest="command")
    add_real(action)
    print(add_custom(CustomBuilder()))


exercise()
