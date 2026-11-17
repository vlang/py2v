from typing import Any


def local_text() -> None:
    records: dict[str, Any] = {"title": "ada"}
    print(records.get("title", "").upper())


def nested_int() -> None:
    records: dict[int, Any] = {1: {"title": "bea"}}
    print(records[1]["title"].upper())


def nested_lookup() -> None:
    records: dict[str, Any] = {"entry": {"title": "gia"}}
    row = records["entry"]
    print(row.get("title", "").upper())


def shared_value() -> None:
    original = {"count": 1}
    records: dict[str, Any] = {"row": original}
    records["row"]["count"] = 2
    print(original["count"])


def bare_parameter(records: dict) -> None:
    print(records["title"].upper())


def explicit_runtime(records: dict[str, Any]) -> None:
    print(records.get("title", "").upper())


def runtime_local(value: Any) -> Any:
    records: dict[str, Any] = {"entry": value}
    return records.get("entry", "")


def empty_runtime() -> dict[str, Any]:
    records: dict[str, Any] = {}
    records["title"] = "ivy"
    return records


def declared_float() -> None:
    records: dict[str, float] = {"value": 1.5}
    print(records["value"])


def rebound() -> None:
    records: dict[str, Any] = {"title": "jay"}
    records = {"title": "kay"}
    print(records["title"])


def bare_return() -> dict:
    return {"title": "eli"}


if __name__ == "__main__":
    local_text()
    nested_int()
    nested_lookup()
    shared_value()
    bare_parameter({"title": "cat"})
    explicit_runtime({"title": "dot"})
    print(runtime_local("hop"))
    print(empty_runtime().get("title", "").upper())
    declared_float()
    rebound()
    print(bare_return()["title"].upper())
