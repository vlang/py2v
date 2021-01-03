import ast
import json
import sys


class AstEncoder(json.JSONEncoder):
    no_main = True

    def default(self, o):
        try:
            return super().default(o)
        except TypeError:
            d = {'@type': o.__class__.__qualname__}
            if isinstance(o, ast.Constant):
                d['@constant_type'] = o.value.__class__.__qualname__
            elif isinstance(o, ast.FunctionDef):  # TODO: improve this
                if o.name == 'main':
                    self.no_main = False

            for name, field in ast.iter_fields(o):
                if isinstance(field, bytes):
                    d[name] = list(field.decode())
                    continue

                d[name] = field
            if isinstance(o, ast.Module):
                d['@no_main'] = self.no_main
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
