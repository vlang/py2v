cutoff = 2
WEIGHTS = {"low": 1, "high": 3}

class Target:
    SELECTED = [key for key, weight in WEIGHTS.items() if weight >= cutoff]

def tuple_labels(positions: dict[tuple[int, int], str], enabled: bool) -> str:
    labels = ["disabled"] if not enabled else [
        label for position, label in positions.items() if position[1] > 1
    ]
    return ":".join(labels)


def total() -> str:
    positions: dict[tuple[int, int], str] = {(0, 1): "low", (0, 2): "high"}
    return ":".join(Target.SELECTED) + "," + tuple_labels(positions, True)
