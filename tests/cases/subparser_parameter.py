import argparse


def add_run(subparsers) -> None:
    run = subparsers.add_parser("run", help="Run a task")
    run.add_argument("name")


def add_nested(subparsers) -> None:
    parent = subparsers.add_parser("group", help="Grouped tasks")
    children = parent.add_subparsers(dest="child", required=True)
    leaf = children.add_parser("leaf")
    leaf.add_argument("--count", type=int, default=2)


def main() -> None:
    parser = argparse.ArgumentParser(prog="builder-test")
    commands = parser.add_subparsers(dest="command", required=True)
    add_run(commands)
    add_nested(commands)
    args = parser.parse_args(["run", "Ada"])
    print(args.command, args.name)
    nested = parser.parse_args(["group", "leaf", "--count", "3"])
    print(nested.command, nested.child, nested.count)
    defaults = parser.parse_args(["group", "leaf"])
    print(defaults.count)


if __name__ == "__main__":
    main()
