import os
from pathlib import Path


def data_file(base: Path, name: str) -> Path:
    return base / "data" / name


def describe(p: Path) -> str:
    return f"{p.name} in {p.parent.name} ({p.suffix}, {p.stem})"


def main() -> None:
    root = Path(os.environ.get("TMPDIR", "/tmp")) / "py2v_pathlib_runtime"
    target = data_file(root, "notes.txt")
    print(target.exists())
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("hello\n")
    print(target.exists(), target.is_file(), target.parent.is_dir())
    print(target.read_text().strip())
    print(describe(target))
    other = target.with_suffix(".bak")
    other.write_text("x")
    names = sorted(p.name for p in target.parent.iterdir())
    print(names)
    print(len(list(target.parent.glob("*.txt"))))
    print(str(target).endswith("notes.txt"))
    other.unlink()
    print(other.exists())
    target.unlink()
    target.parent.rmdir()
    root.rmdir()
    print(root.exists())
    home = Path.home()
    print(home.is_absolute())


if __name__ == "__main__":
    main()
