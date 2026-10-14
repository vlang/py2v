# py2v

A Python to V transpiler. Converts Python source code to the [V programming language](https://vlang.io/).

## Requirements

- [V compiler](https://vlang.io/)
- Python 3.8+

## Building

```bash
cd py2v
v . -o py2v
```

## Usage

```bash
# Output to stdout
py2v input.py

# Output to file
py2v input.py -o output.v

# Translate and immediately compile-check the result
py2v input.py -o output.v --check

# Same for a whole package, checked in parallel
py2v --package ./src -o ./out --check --jobs 8
```

`--check` prints a `module<TAB>errors<TAB>first_error` table on stdout and a summary on
stderr, and exits 1 if any module fails to compile.

## Example

**Python input:**
```python
def fib(i: int) -> int:
    if i == 0 or i == 1:
        return 1
    return fib(i - 1) + fib(i - 2)

if __name__ == "__main__":
    print(fib(5))
```

**V output:**
```v
module main

@[translated]
fn fib(i int) int {
	if i == 0 || i == 1 {
		return 1
	}
	return fib(i - 1) + fib(i - 2)
}

fn main() {
	println(fib(5))
}
```

## Supported Features

- Functions and type annotations
- Classes and methods
- List/dict/set comprehensions
- Generators and iterators
- Exception handling (try/except/finally)
- Context managers (with statements)
- Lambda expressions
- Walrus operator (:=)
- f-strings
- Async/await
- Dataclasses and enums

## Running Tests

The test runner is a V script, so the same command works on every platform:

```bash
v run tests/run_tests.vsh
```

Set `VERBOSE=1` to print expected/generated excerpts for failing cases, or
`PY2V=<path>` to exercise a specific `py2v` binary.

## Translating a Package

`--package` treats the directory as a Python source tree and emits a V project.
One Python *package* becomes one V module, named after its dotted path and
prefixed with `py_`:

```
mypkg/util/digraph.py  ->  out/py_mypkg_util/digraph.v   (module py_mypkg_util)
mypkg/__init__.py     ->  out/py_mypkg/__init__.v
```

V compiles a directory as a single module, so a package's `__init__.py` and its
sibling modules share one namespace in exactly the way Python does. Modules are
kept flat and prefixed so a generated directory can never shadow a vlib module
(`sync`, `term`, …) or start with `_`, which V rejects as a module name.

Absolute, relative (`from . import x`), parent (`from ..pkg import y`) and star
(`from pkg.m import *`) imports are all resolved to the right V module.

## Architecture

py2v uses a two-stage pipeline:

1. **Python frontend** (`frontend/ast_dump.py`) - Parses Python source with the standard library `ast` module, then enriches the tree with type inference, mutability analysis and scope information, and emits it as JSON
2. **V backend** (`parser.v` + `transpiler.v`) - Converts the JSON AST into V code

## License

MIT
