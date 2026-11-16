def hint(path: str, start: int) -> str:
    return (
        f"don't read {path} whole: sed -n '{start}p' {path} | jq "
        "'select(.type==\"user\")' | cut -c1-400"
    )


def quoted(name: str) -> str:
    return f'say "{name}" and it\'s done'


def single(name: str) -> str:
    return f"it's {name}"


print(hint("log.jsonl", 3))
print(quoted("x"))
print(single("y"))
