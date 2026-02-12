class Foo:
    """Foo is a simple test class.

    It has two methods: bar and baz.
    """

    def bar(self):
        return self.baz()

    def baz(self) -> int:
        return 10


if __name__ == "__main__":
    f = Foo()
    b = f.bar()
    print(b)
    assert b == 10
