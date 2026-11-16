import json


def report(names: list[str], scores: dict[str, int]) -> str:
    payload = {"names": names, "count": len(names)}
    return json.dumps(payload, indent=2) + json.dumps(scores, sort_keys=True) + json.dumps(names)


print(report(["b", "a"], {"z": 1, "y": 2}))
print(json.dumps({"a": [1, 2.5, None, True]}, separators=(",", ":")))
