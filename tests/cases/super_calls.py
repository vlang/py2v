class Base:
    value: str

    def __init__(self, value):
        self.value = value

    def greet(self):
        return f"hi {self.value}"


class Child(Base):
    def __init__(self, value):
        super().__init__(value)

    def greet(self):
        return super().greet()


class CustomError(Exception):
    def __init__(self, msg):
        super().__init__(msg)


if __name__ == "__main__":
    c = Child("x")
    print(c.greet())
