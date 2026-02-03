# py2v

A Python to V transpiler. Converts Python source code to the [V programming language](https://vlang.io/).

## Requirements

- [V compiler](https://vlang.io/)
- Python 3.8+
- [py2many](https://github.com/py2many/py2many) - `pip install py2many`

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
```

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
@[translated]
module main

fn fib(i int) int {
    if i == 0 || i == 1 {
        return 1
    }
    return fib((i - 1)) + fib((i - 2))
}

fn main() {
    println((fib(5)).str())
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

```bash
cd tests
sh run_tests.sh
```

## Architecture

py2v uses a two-stage pipeline:

1. **Python frontend** (`frontend/ast_dump.py`) - Parses Python source using py2many's analysis passes, enriches the AST with type inference and scope information, outputs JSON
2. **V backend** (`transpiler.v`) - Consumes the JSON AST and generates V code

## License

MIT
