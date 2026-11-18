from typing import Any


def caught(values: list[Any]) -> None:
    try:
        result = [err.append(1) for err in values]
        print(len(result))
    except AttributeError:
        print("caught")


def messages(values: list[Any], py2v_comp_err_0: str) -> None:
    result = [err["message"] if err.get("message") else err.get("error", "") for err in values]
    print(py2v_comp_err_0)
    for value in result:
        print(value)


if __name__ == "__main__":
    caught([[]])
    caught([1])
    messages([{"message": "one"}, {"error": "two"}], "pyrt.fail(err)")
