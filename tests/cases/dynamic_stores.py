from typing import Any


def fill(status: dict[str, Any], record, text) -> None:
    status["tasks"]["total"] = 3
    status["tasks"]["names"] = ["a", "b"]
    record["count"] = record["count"] + 1
    record["seen"] = True
    print(status["tasks"]["total"], record["count"], record["seen"])
    print(text[:3], text[1:], text[1:3])
    head = record["title"][:5]
    print(head, len(head))
    print(status["tasks"]["names"][0])


if __name__ == "__main__":
    fill({"tasks": {"total": 0}}, {"count": 1, "title": "hello world"}, "abcdef")
