import ast
import json
import sys

BASE = set(dir(object()))


def filter_attr(attr: str) -> bool:
    if attr in BASE:
        return False

    if attr.startswith('_') or attr.endswith('_'):
        return False

    return True


class AstEncoder(json.JSONEncoder):
    def default(self, o):
        try:
            return super().default(o)
        except TypeError:
            d = {'@type': o.__class__.__qualname__}
            for attr in filter(filter_attr, dir(o)):
                d[attr] = getattr(o, attr)
            return d


def main():
    if len(sys.argv) < 3:
        print(f'USAGE: {sys.argv[0]} <source> <destination>')
        sys.exit(1)

    with open(sys.argv[1]) as f:
        node = ast.parse(f.read())

    with open(sys.argv[2], 'w') as f:
        json.dump(node, f, cls=AstEncoder, indent=2)


if __name__ == "__main__":
    main()
