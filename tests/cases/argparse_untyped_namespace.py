#!/usr/bin/env python3
import argparse


def cmd_list(args):
    print("list", args.limit, args.verbose)
    if args.name:
        print("name", args.name)
    return 0


def cmd_add(args):
    total = args.limit + 1
    print("add", args.item, total)
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="tool")
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--name")
    parser.add_argument("item")
    args = parser.parse_args(argv)
    if args.verbose:
        return cmd_list(args)
    return cmd_add(args)


if __name__ == "__main__":
    main(["thing", "--limit", "2"])
    main(["thing", "--verbose", "--name", "n"])
