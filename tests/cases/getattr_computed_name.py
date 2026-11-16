class Args:
    def __init__(self) -> None:
        self.a_bin = "x"
        self.only = []


ORIGINALS = ["a"]
args = Args()
selected = args.only or [name for name in ORIGINALS if getattr(args, f"{name}_bin")]
print(getattr(args, "a_bin"), hasattr(args, "only"))
name = "a_bin"
setattr(args, name, "y")
print(getattr(args, name, None))
