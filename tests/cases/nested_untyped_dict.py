import json


def schema(name: str, count: int) -> dict:
    return {
        "name": name,
        "type": "object",
        "count": count,
        "properties": {
            "object_id": {"type": "string", "description": "the id"},
            "limit": {"type": "integer", "default": 10},
        },
        "required": ["object_id"],
        "evidence": {"status": "attached" if count > 0 else "none", "inherited": count},
    }


def main() -> None:
    s = schema("capsule", 2)
    print(json.dumps(s, sort_keys=True))
    print(s["properties"]["limit"]["default"])


if __name__ == "__main__":
    main()
