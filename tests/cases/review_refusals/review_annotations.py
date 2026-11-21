from typing import Any, Optional

def take_text(s: Optional[str]) -> str:
    return s if s is not None else 'none'

def take_sequence(s: tuple[str, ...]) -> str:
    return ''.join(s)

def run(x: Any) -> None:
    try:
        print(take_text(x))
    except TypeError:
        print('type')
    try:
        print(take_sequence(x))
    except TypeError:
        print('seq-type')

run('xy')
run(4)
run(None)
