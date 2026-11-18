from typing import List, Optional, cast

if __name__ == "__main__":
    print(cast(list["int"], 1))
    print(cast(tuple["str", ...], 2))
    print(cast(dict[str, "bool"], 3))
    print(cast(Optional, 4))
    print(cast(List[list["int"]], 5))
