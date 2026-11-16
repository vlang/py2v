class ConfigError(Exception):
    pass


class MissingKey(ConfigError):
    pass


def check(n: int) -> int:
    if n < 0:
        raise ValueError(f"negative: {n}")
    if n == 13:
        raise RuntimeError("unlucky", n)
    return n * 2


def read(key: str) -> str:
    if key == "":
        raise MissingKey("empty key")
    if key == "bad":
        raise ConfigError("bad key")
    return key.upper()


def safe(n: int) -> int:
    try:
        return check(n)
    except ValueError as e:
        print("caught", e)
        return 0


def describe(key: str) -> str:
    try:
        value = read(key)
        if value == "STOP":
            raise ConfigError("stop requested")
    except MissingKey as e:
        return "missing: " + str(e)
    except ConfigError as e:
        return "config: " + str(e)
    return "ok " + value


def relay(n: int) -> int:
    try:
        return check(n)
    except RuntimeError:
        print("relaying")
        raise


def outer(n: int) -> str:
    try:
        return str(relay(n))
    except Exception as e:
        return "outer got " + str(e)


def main() -> None:
    print(safe(2), safe(-1))
    print(describe("a"), "|", describe(""), "|", describe("bad"), "|", describe("stop"))
    print(outer(4), "|", outer(13), "|", outer(-5))


if __name__ == "__main__":
    main()
