def classify(status: int) -> str:
    match status:
        case 200:
            return "OK"
        case 404:
            return "Not Found"
        case 500:
            return "Server Error"
        case _:
            return "Unknown"


def direction(cmd: str) -> str:
    match cmd:
        case "north" | "south":
            return "vertical"
        case "east" | "west":
            return "horizontal"
        case _:
            return "unknown"


def check_singleton(val):
    match val:
        case True:
            return "yes"
        case False:
            return "no"
        case None:
            return "nothing"
        case _:
            return "other"


if __name__ == "__main__":
    print(classify(200))
    print(classify(404))
    print(classify(999))
    print(direction("north"))
    print(direction("east"))

