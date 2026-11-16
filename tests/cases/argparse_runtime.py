import argparse


def build() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="tool", description="Demo tool")
    parser.add_argument("name", help="who to greet")
    parser.add_argument("--count", "-c", type=int, default=2, help="how many times")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--mode", choices=["fast", "slow"], default="fast")
    parser.add_argument("--tag", action="append", default=[])
    return parser


def main() -> None:
    parser = build()
    args = parser.parse_args(["world", "--count", "3", "--verbose", "--tag", "a", "--tag", "b"])
    for _ in range(args.count):
        print("hello", args.name)
    if args.verbose:
        print("mode", args.mode, "tags", args.tag)
    other = parser.parse_args(["x"])
    print(other.count, other.verbose, other.mode, other.tag)


if __name__ == "__main__":
    main()
