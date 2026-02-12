class Config:
    """Config holds application settings."""

    debug = False
    max_retries = 3
    name = "default"
    ratio = 0.5


class ProxyType:
    DIRECT = 0
    MANUAL = 1


if __name__ == "__main__":
    c = Config()
    print(c.debug)
    print(c.max_retries)
    print(c.name)
    print(c.ratio)
    print(ProxyType.DIRECT)
