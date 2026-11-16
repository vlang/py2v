import json


def load(text: str) -> str:
    data = json.loads(text)
    return json.dumps(data)


print(load('[1, 2.5, "a", null, true]'))
