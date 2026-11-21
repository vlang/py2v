from enum import Enum, auto


class Target(Enum):
    PY39 = 9
    PY312 = 12

    def pretty(self) -> str:
        return f"Python {self.name[2]}.{self.name[3:]}"


class Selection(Enum):
    stable = auto()
    preview = auto()


def lookup_target(label: str) -> Target:
    return Target[label]


def lookup_options(labels: list[str]) -> list[Selection]:
    return [Selection[label] for label in labels]


if __name__ == "__main__":
    target = lookup_target("PY312")
    print(target, target.value, target.name, target.pretty())
    for option in lookup_options(["preview", "stable"]):
        print(option.name, option.value)
    try:
        lookup_target("py312")
    except KeyError:
        print("missing")
