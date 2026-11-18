from collections import defaultdict
from typing import Any


def size(values: defaultdict[Any, Any]) -> int:
    return len(values)


values = defaultdict(Any)
print(size(values))
