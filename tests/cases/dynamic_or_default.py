#!/usr/bin/env python3


def show(record, fallback):
    name = record.get("name") or "nobody"
    tags = record.get("tags") or []
    count = record["count"] or 0
    date = (record.get("when") or "")[:4]
    owner = record.get("owner") or fallback
    both = record.get("name") and fallback
    print(name, len(tags), count, date, owner, both)
    if record.get("name") or record.get("owner"):
        print("named")


if __name__ == "__main__":
    show({"name": "ada", "count": 3, "when": "2026-11-16"}, "x")
    show({"count": 0, "tags": ["a"], "owner": "o"}, "y")
    show({"count": 2}, "z")
