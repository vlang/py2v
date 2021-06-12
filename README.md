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
<path to V> -prod py2v.v -o py2v
```

## Usage

```
./py2v <Python input file> <V output file>
# put - as output file to print output to terminal
```

## Contributing

PRs are welcome. Please prefix your PR titles with the component you are editing. (`docs: improve README.md` etc.)

## License

[MIT License](/LICENSE)
