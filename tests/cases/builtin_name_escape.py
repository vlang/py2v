def make_pair(string, int):
    return {"name": string, "value": int}


def get_value():
    return 42


if __name__ == "__main__":
    result = make_pair("hello", 10)
    print(result)
    print(get_value())
