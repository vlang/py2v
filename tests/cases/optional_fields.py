class BaseOptions:
    def __init__(self) -> None:
        self.mobile_options: dict[str, str] | None = None
        self.names: list[str] | None = None
        self.count: int | None = None
