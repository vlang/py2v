from pathlib import Path

p = Path("data.txt")
content = p.read_text()
p.write_text("hello world")
exists = p.exists()
is_f = p.is_file()
is_d = p.is_dir()
name = p.name
parent = p.parent

# Path joining with /
sub = p.parent / "subdir" / "out.txt"

# mkdir and unlink
Path("newdir").mkdir(parents=True, exist_ok=True)
p.unlink()

# iterdir and glob
for f in Path(".").iterdir():
    print(f)

files = list(Path(".").glob("*.txt"))
print(files)

