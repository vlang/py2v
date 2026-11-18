def get_number() -> int:
    print("DEFAULT_EVAL")
    return 8
def run() -> int:
    def inner(v: int = get_number()) -> int:
        return v
    return inner() + inner()
print(run())
