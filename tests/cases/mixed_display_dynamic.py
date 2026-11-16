#!/usr/bin/env python3
import json


def describe(record, label: str) -> str:
    summary = {
        "label": label,
        "name": record.get("name"),
        "count": record["count"],
        "tags": ["a", "b"],
        "ok": True,
    }
    row = [label, record["count"], 1.5]
    return json.dumps(summary) + " " + json.dumps(row)


if __name__ == "__main__":
    print(describe({"name": "ada", "count": 3}, "x"))
