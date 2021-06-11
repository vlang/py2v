# py2v

py2v is a Python to V source transpiler written (mostly) in V. py2v aims not to have a bug-to-bug 100% accurate transpilation but to create a baseline to ease re-making Python projects in V.

Please see the [examples folder](/examples/) to see the least py2v can do.

## Installation

Dependencies:
- [V](https://github.com/vlang/v)
- Python 3.6+

```bash
git clone https://github.com/vlang/py2v.git
cd py2v

# only use next command if you don't have V on PATH
./v -prod json2v -o json2v/json2v
```

## Usage

```
./py2v.sh <Python input file> <V output file>
```

## Contributing

PRs are welcome. Please prefix your PR titles with the component you are editing. (`docs: improve README.md` etc.)

## License

[MIT License](/LICENSE)
