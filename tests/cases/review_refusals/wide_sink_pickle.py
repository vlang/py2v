from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def probe(value: Word) -> None:
    import pickle
    print(pickle.loads(pickle.dumps(value)))


probe(HIGH)
