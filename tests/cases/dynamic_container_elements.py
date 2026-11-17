from typing import Any


def list_element(rows: list[Any]) -> None:
    print(rows[0]["name"].strip())
    name = rows[0]["name"]
    print(len(name))
    print(name[1:3])


def dict_element(record: dict[str, Any]) -> None:
    names = record["names"]
    print(names[0].upper())
    for name in names:
        print(name.strip())


def typed_element(names: list[str]) -> str:
    return names[0].strip()


if __name__ == "__main__":
    list_element([{"name": " ada "}])
    dict_element({"names": [" ada ", " bob "]})
    print(typed_element([" typed "]))
