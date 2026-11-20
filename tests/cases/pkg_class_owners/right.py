class Point:
    label: str

    def __init__(self, label: str) -> None:
        self.label = label

    def text(self) -> str:
        return self.label

    @classmethod
    def tagged(cls, label: str) -> str:
        return label + "!"
